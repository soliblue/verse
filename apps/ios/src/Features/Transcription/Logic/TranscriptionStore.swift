import AVFoundation
import ActivityKit
import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class TranscriptionStore {
    static let shared = TranscriptionStore()
    let recorder = VoiceRecorder()
    let api = SpeechAPI()
    var items: [Transcription] = []
    var models = ["small", "medium", "large-v3"]
    var error: String?
    var isUploading = false
    var isRefreshing = false
    var isStartingRecording = false
    var keyboardExpiresAt: Date?
    var pendingAudio: [URL] = []
    private var timer: Timer?
    private var lastPoll = Date.distantPast
    private var keyboardJobID = ""
    private var uploadBackgroundTask = UIBackgroundTaskIdentifier.invalid
    private let demo = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    private var interruptionTask: Task<Void, Never>?
    private var activity: Activity<DictationActivityAttributes>?
    private var activityTask: Task<Void, Never>?
    private var sessionGeneration = 0
    private var recordingUpload: RecordingUpload?

    init() {
        if VerseBridge.token.isEmpty {
            VerseBridge.token = KeychainStore.value(for: "device-secret")
        }
        VerseBridge.sessionExpiresAt = 0
        VerseBridge.isRecording = false
        VerseBridge.audioLevel = 0
        VerseBridge.acknowledgedCommandID = VerseBridge.commandID
        if demo {
            items = [.preview]
            return
        }
        if let data = try? Data(contentsOf: cacheURL), let cached = try? JSONDecoder().decode([Transcription].self, from: data) {
            items = cached
        }
        loadPendingAudio()
        interruptionTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification) {
                if let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                   type == AVAudioSession.InterruptionType.began.rawValue {
                    self?.perform { [weak self] in try await self?.endSession() }
                }
            }
        }
        let previousActivities = Activity<DictationActivityAttributes>.activities
        Task {
            for activity in previousActivities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    var isConfigured: Bool { demo || !VerseBridge.token.isEmpty }

    func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        Task {
            let result = await Task { try await operation() }.result
            if case .failure(let failure) = result {
                await reportFailure(failure)
            }
        }
    }

    func reportFailure(_ failure: Error) async {
        VerseBridge.audioLevel = 0
        error = failure.localizedDescription
        VerseBridge.errorText = failure.localizedDescription
        VerseBridge.statusText = ""
        loadPendingAudio()
        await updateActivity(recorder.isRecording ? "recording" : "ready")
    }

    func refresh() async throws {
        guard !demo, isConfigured, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let previous = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.state) })
        items = try await api.history()
        try JSONEncoder().encode(items).write(to: cacheURL, options: .atomic)
        for item in items where item.state == "completed" && previous[item.id] != nil && previous[item.id] != "completed" {
            await notify(item)
        }
        let jobID = keyboardJobID.isEmpty ? VerseBridge.pendingJobID : keyboardJobID
        if let item = items.first(where: { $0.id == jobID }), !item.isPending {
            VerseBridge.statusText = ""
            if item.state == "completed" {
                VerseBridge.transcriptText = item.text ?? ""
                VerseBridge.transcriptID = item.id
                VerseBridge.errorText = ""
                if VerseBridge.pendingInsertionJobID == item.id {
                    VerseBridge.insertionTranscriptID = item.id
                    VerseBridge.insertionReadyAt = Date().timeIntervalSince1970
                    VerseBridge.pendingInsertionJobID = ""
                }
            } else { VerseBridge.errorText = item.error ?? "Transcription failed. Try again in Verse." }
            keyboardJobID = ""
            VerseBridge.pendingJobID = ""
            await updateActivity(recorder.isRecording ? "recording" : "ready")
        }
    }

    func checkConnection() async throws {
        guard !demo else { return }
        error = nil
        models = try await api.configuration().models
        try await refresh()
    }

    func toggleRecording() async throws {
        guard !isStartingRecording else { return }
        guard isConfigured else { throw SpeechFailure("Add your device token in Settings first.") }
        guard !isUploading || recorder.isRecording else { throw SpeechFailure("Wait for this recording to upload.") }
        if recorder.isRecording {
            try await finishRecording()
        } else {
            isStartingRecording = true
            defer { isStartingRecording = false }
            let generation = sessionGeneration
            try await recorder.activate()
            guard generation == sessionGeneration else {
                recorder.deactivate()
                throw SpeechFailure("Dictation session ended.")
            }
            try recorder.begin()
            if let url = recorder.fileURL { recordingUpload = RecordingUpload(url: url) }
            VerseBridge.isRecording = true
            VerseBridge.errorText = ""
            await updateActivity("recording")
        }
    }

    func toggleSystemDictation() async throws {
        guard !isStartingRecording else { return }
        if recorder.isRecording {
            try await finishRecording()
        } else {
            guard AVAudioApplication.shared.recordPermission == .granted else {
                throw SpeechFailure("Open Verse once and allow microphone access before using dictation controls.")
            }
            try await startKeyboardDictation()
        }
    }

    func startKeyboardDictation() async throws {
        guard !recorder.isRecording, !isStartingRecording else { return }
        guard !isUploading, VerseBridge.pendingJobID.isEmpty else {
            throw SpeechFailure("Wait for your last transcription to finish.")
        }
        let generation = sessionGeneration
        try await activateKeyboard()
        guard generation == sessionGeneration else { throw SpeechFailure("Dictation session ended.") }
        guard !recorder.isRecording else { return }
        VerseBridge.insertionTranscriptID = ""
        try await toggleRecording()
    }

    func activateKeyboard() async throws {
        guard !isStartingRecording else { return }
        guard isConfigured else { throw SpeechFailure("Add your device token in Settings first.") }
        isStartingRecording = true
        defer { isStartingRecording = false }
        let generation = sessionGeneration
        if activity == nil {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                throw SpeechFailure("Allow Live Activities for Verse in iPhone Settings to use background dictation.")
            }
            activity = try Activity.request(
                attributes: DictationActivityAttributes(),
                content: ActivityContent(state: .init(phase: "ready", startedAt: Date()), staleDate: nil),
                pushType: nil
            )
            let observedActivity = activity!
            activityTask?.cancel()
            activityTask = Task { [weak self] in
                for await state in observedActivity.activityStateUpdates {
                    if state == .dismissed || state == .ended {
                        guard !Task.isCancelled else { return }
                        self?.perform { [weak self] in
                            if self?.activity?.id == observedActivity.id {
                                try await self?.endSession()
                            }
                        }
                        return
                    }
                }
            }
        }
        let activation = await Task { try await recorder.activate() }.result
        if case .failure = activation {
            await endActivity()
        }
        try activation.get()
        guard generation == sessionGeneration else {
            recorder.deactivate()
            throw SpeechFailure("Dictation session ended.")
        }
        keyboardExpiresAt = Date().addingTimeInterval(VerseBridge.sessionDuration)
        VerseBridge.sessionExpiresAt = keyboardExpiresAt!.timeIntervalSince1970
        VerseBridge.sessionHeartbeatAt = Date().timeIntervalSince1970
        VerseBridge.errorText = ""
        VerseBridge.statusText = "Ready"
    }

    func endSession() async throws {
        sessionGeneration += 1
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Finish dictation")
        defer {
            if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
        }
        keyboardExpiresAt = nil
        VerseBridge.sessionExpiresAt = 0
        VerseBridge.sessionHeartbeatAt = 0
        let result = Result { try recorder.finish() }
        if case .failure = result { recordingUpload?.cancel(); recordingUpload = nil }
        recorder.deactivate()
        VerseBridge.isRecording = false
        VerseBridge.audioLevel = 0
        await endActivity()
        let url = try result.get()
        if let url { try await upload(url, keyboard: true) }
    }

    func finishRecording() async throws {
        let keyboard = keyboardExpiresAt != nil
        let result = Result { try recorder.finish() }
        if case .failure = result { recordingUpload?.cancel(); recordingUpload = nil }
        VerseBridge.isRecording = false
        VerseBridge.audioLevel = 0
        if keyboardExpiresAt == nil { recorder.deactivate() }
        await updateActivity("transcribing")
        let url = try result.get()
        if let url { try await upload(url, keyboard: keyboard) }
    }

    func importAudio(_ url: URL) async throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 52_428_800 else { throw SpeechFailure("Choose an audio file smaller than 50 MB.") }
        let folder = pendingDirectory
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        try FileManager.default.copyItem(at: url, to: destination)
        try await upload(destination)
    }

    func upload(_ url: URL, keyboard: Bool = false) async throws {
        guard !isUploading else { throw SpeechFailure("Wait for the current upload to finish.") }
        isUploading = true
        VerseBridge.statusText = "Uploading…"
        uploadBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Upload recording") { [weak self] in
            Task { @MainActor in self?.endUploadBackgroundTask() }
        }
        defer {
            isUploading = false
            endUploadBackgroundTask()
            loadPendingAudio()
        }
        let streaming = recordingUpload?.url == url ? recordingUpload : nil
        let prepared = try await streaming?.finish()
        let item: Transcription
        if let prepared { item = prepared }
        else { item = try await api.upload(url) }
        if streaming != nil { recordingUpload = nil }
        items.insert(item, at: 0)
        VerseBridge.statusText = "Transcribing…"
        VerseBridge.pendingJobID = item.id
        if keyboard {
            keyboardJobID = item.id
            VerseBridge.pendingInsertionJobID = item.id
        }
        try JSONEncoder().encode(items).write(to: cacheURL, options: .atomic)
        try FileManager.default.removeItem(at: url)
    }

    func delete(_ item: Transcription) async throws {
        if !demo { try await api.delete(item.id) }
        items.removeAll { $0.id == item.id }
        if VerseBridge.pendingJobID == item.id {
            VerseBridge.pendingJobID = ""
            VerseBridge.statusText = ""
        }
        if keyboardJobID == item.id { keyboardJobID = "" }
        if VerseBridge.transcriptID == item.id {
            VerseBridge.transcriptID = ""
            VerseBridge.transcriptText = ""
        }
        try JSONEncoder().encode(items).write(to: cacheURL, options: .atomic)
    }

    private func tick() {
        if recorder.isRecording { VerseBridge.audioLevel = recorder.audioLevel }
        if keyboardExpiresAt != nil, Date().timeIntervalSince1970 - VerseBridge.sessionHeartbeatAt >= 1 {
            VerseBridge.sessionHeartbeatAt = Date().timeIntervalSince1970
        }
        if let expiry = keyboardExpiresAt, expiry <= Date() {
            keyboardExpiresAt = nil
            perform { try await self.endSession() }
        }
        if recorder.isRecording, Date().timeIntervalSince(recorder.startedAt) >= 300 {
            perform { try await self.finishRecording() }
        }
        let command = VerseBridge.commandID
        if command != VerseBridge.acknowledgedCommandID {
            VerseBridge.acknowledgedCommandID = command
            let action = VerseBridge.commandAction
            if keyboardExpiresAt != nil {
                if action == "start", !recorder.isRecording, !isUploading, VerseBridge.pendingJobID.isEmpty {
                    VerseBridge.insertionTranscriptID = ""
                    perform { try await self.toggleRecording() }
                } else if action == "stop", recorder.isRecording {
                    perform { try await self.finishRecording() }
                }
            }
        }
        if Date().timeIntervalSince(lastPoll) >= 2,
           items.contains(where: \.isPending) || !VerseBridge.pendingJobID.isEmpty {
            lastPoll = Date()
            perform { try await self.refresh() }
        }
    }

    private func notify(_ item: Transcription) async {
        guard UserDefaults.standard.bool(forKey: "verse.completionNotifications"), UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = "Transcription ready"
        content.body = "Open Verse to read and copy your transcript."
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: item.id, content: content, trigger: nil))
    }

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("transcriptions.json")
    }

    private var pendingDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PendingAudio", isDirectory: true)
    }

    private func loadPendingAudio() {
        guard !recorder.isRecording else { return }
        pendingAudio = (try? FileManager.default.contentsOfDirectory(at: pendingDirectory, includingPropertiesForKeys: nil)) ?? []
    }

    func discardPending(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
        loadPendingAudio()
    }

    private func endUploadBackgroundTask() {
        if uploadBackgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(uploadBackgroundTask)
            uploadBackgroundTask = .invalid
        }
    }

    private func updateActivity(_ phase: String) async {
        await activity?.update(ActivityContent(state: .init(phase: phase, startedAt: recorder.startedAt), staleDate: keyboardExpiresAt))
    }

    private func endActivity() async {
        activityTask?.cancel()
        activityTask = nil
        let ending = activity
        activity = nil
        await ending?.end(nil, dismissalPolicy: .immediate)
    }
}
