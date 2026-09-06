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
    let localEngine = LocalSpeechEngine()
    let writing = AppleWritingService.shared
    let library = TranscriptionLibrary()
    var items: [Transcription] = []
    var models = ["small", "medium", "large-v3"]
    var error: String?
    var isUploading = false
    var isRefreshing = false
    var isStartingRecording = false
    private(set) var rerunningRecordingID: String?
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
    private var recordingSelection: SpeechSelection?
    private var deletingRecordingIDs = Set<String>()

    init() {
        if VerseBridge.token.isEmpty {
            VerseBridge.token = KeychainStore.value(for: "device-secret")
        }
        VerseBridge.sessionExpiresAt = 0
        VerseBridge.isRecording = false
        VerseBridge.recordingStartedAt = 0
        VerseBridge.acknowledgedCommandID = VerseBridge.commandID
        if demo {
            VerseBridge.onDeviceTranscriptionEnabled = true
            VerseBridge.localModel = "medium"
            VerseBridge.writingStyle = "original"
            VerseBridge.writingEnabled = false
            VerseBridge.customWritingPrompt = ""
            VerseBridge.typingKeyboardEnabled = false
            if ProcessInfo.processInfo.arguments.contains("--history-ui-testing") { items = Transcription.previewHistory }
            else if ProcessInfo.processInfo.arguments.contains("--versions-ui-testing") { items = Transcription.previewVersions }
            else { items = [.preview] }
            return
        }
        items = library.load().filter { !VerseBridge.isDeleted($0.id) }
        if VerseBridge.pendingJobID.hasPrefix("local-") {
            VerseBridge.pendingJobID = ""
            VerseBridge.pendingInsertionJobID = ""
            VerseBridge.statusText = ""
        }
        VerseBridge.localInstalledModels = localEngine.installedModelIDs.sorted().joined(separator: ",")
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

    var isConfigured: Bool { demo || VerseBridge.onDeviceTranscriptionEnabled || !VerseBridge.token.isEmpty }
    var isRerunning: Bool { rerunningRecordingID != nil }
    var recordings: [Transcription] { Transcription.recordings(from: items) }

    func versions(for id: String) -> [Transcription] { Transcription.versions(for: id, in: items) }

    func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        Task {
            let result = await Task { try await operation() }.result
            if case .failure(let failure) = result {
                await reportFailure(failure)
            }
        }
    }

    func reportFailure(_ failure: Error) async {
        error = failure.localizedDescription
        VerseBridge.errorText = failure.localizedDescription
        VerseBridge.statusText = ""
        loadPendingAudio()
        await updateActivity(recorder.isRecording ? "recording" : "ready")
    }

    func refresh() async throws {
        guard !demo, !VerseBridge.token.isEmpty, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let previous = Dictionary(items.map { ($0.id, $0.state) }, uniquingKeysWith: { _, last in last })
        let pendingID = VerseBridge.pendingJobID
        var remote = try await api.history()
        remote.removeAll { VerseBridge.isDeleted($0.id) }
        for index in remote.indices where remote[index].state == "completed" {
            let item = remote[index]
            if VerseBridge.options(for: item.id) != nil || VerseBridge.rewriteResult(for: item.id) != nil {
                remote[index] = item.applying(await TranscriptDelivery.prepare(id: item.id, text: item.text ?? "", language: item.detectedLanguage))
            }
        }
        remote.removeAll { VerseBridge.isDeleted($0.id) }
        items = TranscriptionLibrary.merging(server: remote, cached: items.filter { !VerseBridge.isDeleted($0.id) })
        try library.save(items)
        for item in items where item.state == "completed" && previous[item.id] != "completed" && (previous[item.id] != nil || item.id == pendingID) {
            await notify(item)
        }
        let jobID = keyboardJobID.isEmpty ? VerseBridge.pendingJobID : keyboardJobID
        if let item = items.first(where: { $0.id == jobID }), !item.isPending {
            VerseBridge.publishTranscriptionResult(id: item.id, statusCode: 200, state: item.state, text: item.text, error: item.error)
            keyboardJobID = ""
            await updateActivity(recorder.isRecording ? "recording" : "ready")
        }
    }

    func checkConnection() async throws {
        guard !demo else { return }
        error = nil
        models = try await api.configuration().models
        try await refresh()
    }

    func toggleRecording(origin: TranscriptionOrigin = .app) async throws {
        guard !isStartingRecording else { return }
        guard !isRerunning else { throw SpeechFailure("Wait for this transcription to finish.") }
        guard isConfigured else { throw SpeechFailure("Add your device token in Settings first.") }
        guard !isUploading || recorder.isRecording else { throw SpeechFailure("Wait for this recording to upload.") }
        if recorder.isRecording {
            try await finishRecording()
        } else {
            let selection = SpeechSelection.current
            try validateSelection(selection)
            isStartingRecording = true
            defer { isStartingRecording = false }
            let generation = sessionGeneration
            try await recorder.activate()
            guard generation == sessionGeneration else {
                recorder.deactivate()
                throw SpeechFailure("Dictation session ended.")
            }
            try recorder.begin(origin: origin)
            recordingSelection = selection
            if let url = recorder.fileURL {
                let saved = Result { try library.saveSelection(selection, for: url) }
                if case .failure = saved {
                    _ = try? recorder.finish()
                    if keyboardExpiresAt == nil { recorder.deactivate() }
                }
                try saved.get()
                if selection.onDevice { localEngine.warm(selection.model) }
                else { recordingUpload = RecordingUpload(url: url, selection: selection) }
            }
            writing.prewarm(style: selection.style, customPrompt: selection.customPrompt)
            VerseBridge.isRecording = true
            VerseBridge.recordingStartedAt = recorder.startedAt.timeIntervalSince1970
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
        guard !isUploading, !isRerunning, VerseBridge.pendingJobID.isEmpty else {
            throw SpeechFailure("Wait for your last transcription to finish.")
        }
        let generation = sessionGeneration
        try await activateKeyboard()
        guard generation == sessionGeneration else { throw SpeechFailure("Dictation session ended.") }
        guard !recorder.isRecording else { return }
        VerseBridge.insertionTranscriptID = ""
        try await toggleRecording(origin: .keyboard)
    }

    func activateKeyboard() async throws {
        guard !isStartingRecording else { return }
        guard isConfigured else { throw SpeechFailure("Add your device token in Settings first.") }
        try validateSelection(.current)
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
        let selection = SpeechSelection.current
        if selection.onDevice { localEngine.warm(selection.model) }
        writing.prewarm(style: selection.style, customPrompt: selection.customPrompt)
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
        VerseBridge.recordingStartedAt = 0
        await endActivity()
        let url = try result.get()
        if let url { try await upload(url) }
    }

    func finishRecording() async throws {
        let result = Result { try recorder.finish() }
        if case .failure = result { recordingUpload?.cancel(); recordingUpload = nil }
        VerseBridge.isRecording = false
        VerseBridge.recordingStartedAt = 0
        if keyboardExpiresAt == nil { recorder.deactivate() }
        await updateActivity("transcribing")
        let url = try result.get()
        if let url { try await upload(url) }
    }

    func importAudio(_ url: URL) async throws {
        guard !isRerunning else { throw SpeechFailure("Wait for this transcription to finish.") }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 52_428_800 else { throw SpeechFailure("Choose an audio file smaller than 50 MB.") }
        let folder = library.pendingDirectory
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent("Import-\(UUID().uuidString)-\(url.lastPathComponent)")
        try FileManager.default.copyItem(at: url, to: destination)
        try library.saveSelection(.current, for: destination)
        try await upload(destination)
    }

    @discardableResult
    func upload(_ url: URL) async throws -> Transcription {
        guard !isUploading, !recorder.isRecording else { throw SpeechFailure("Finish the current recording first.") }
        let savedPending = library.pendingTranscription(for: url)
        if url.lastPathComponent.hasPrefix("Rerun-") {
            guard savedPending?.isRerun == true else { throw SpeechFailure("Run this transcription again from the original recording.") }
        }
        let selection = savedPending?.selection ?? recordingSelection ?? .current
        try library.saveSelection(selection, for: url)
        let pending = library.pendingTranscription(for: url) ?? PendingTranscription(selection: selection)
        let isRerun = pending.isRerun
        if let recordingID = pending.recordingID {
            guard !deletingRecordingIDs.contains(recordingID), items.contains(where: { $0.recordingKey == recordingID }) else {
                throw SpeechFailure("This recording is no longer in your library.")
            }
        }
        recordingSelection = nil
        try validateSelection(selection)
        let ownsRerun = isRerun && rerunningRecordingID == nil
        if ownsRerun { rerunningRecordingID = pending.recordingID }
        isUploading = true
        if !isRerun { VerseBridge.statusText = selection.onDevice ? "Transcribing…" : "Uploading…" }
        uploadBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Upload recording") { [weak self] in
            Task { @MainActor in self?.endUploadBackgroundTask() }
        }
        defer {
            isUploading = false
            if ownsRerun { rerunningRecordingID = nil }
            endUploadBackgroundTask()
            loadPendingAudio()
        }
        if selection.onDevice {
            return try await transcribeLocally(url, pending: pending)
        }
        let streaming = recordingUpload?.url == url ? recordingUpload : nil
        let prepared = try await streaming?.finish()
        var item: Transcription
        if let prepared { item = prepared }
        else { item = try await api.upload(url, selection: selection, origin: pending.origin) }
        if streaming != nil { recordingUpload = nil }
        item.recordingID = pending.recordingID
        item.origin = pending.origin ?? item.origin ?? TranscriptionOrigin.pendingAudio(url)
        item.filename = pending.filename ?? item.filename
        item.localAudioName = try library.keepAudio(url, id: item.recordingKey, existingName: pending.localAudioName)
        item.customPrompt = selection.customPrompt
        item.writingStyle = selection.style.rawValue
        VerseBridge.saveOptions(selection, for: item.id)
        if item.state == "completed" {
            item = item.applying(await TranscriptDelivery.prepare(id: item.id, text: item.text ?? "", language: item.detectedLanguage))
        }
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        if !isRerun {
            VerseBridge.statusText = "Transcribing…"
            VerseBridge.pendingJobID = item.id
            if TranscriptionOrigin.pendingAudio(url) == .keyboard {
                keyboardJobID = item.id
                VerseBridge.pendingInsertionJobID = item.id
            }
        }
        try library.save(items)
        try library.removePending(url)
        if !item.isPending {
            if !isRerun {
                VerseBridge.publishTranscriptionResult(id: item.id, statusCode: 200, state: item.state, text: item.text, error: item.error)
                keyboardJobID = ""
            }
            await notify(item)
        }
        return item
    }

    private func transcribeLocally(_ url: URL, pending: PendingTranscription) async throws -> Transcription {
        let selection = pending.selection
        let id = TranscriptionLibrary.localID(for: url)
        if let existing = items.first(where: { $0.id == id && $0.state == "completed" }) {
            if !pending.isRerun {
                VerseBridge.pendingJobID = id
                VerseBridge.publishTranscriptionResult(id: id, statusCode: 200, state: existing.state, text: existing.text, error: nil)
            }
            try library.removePending(url)
            return existing
        }
        let origin = pending.origin ?? TranscriptionOrigin.pendingAudio(url)
        VerseBridge.saveOptions(selection, for: id)
        if !pending.isRerun {
            VerseBridge.pendingJobID = id
            if origin == .keyboard { VerseBridge.pendingInsertionJobID = id }
        }
        defer {
            if VerseBridge.pendingJobID == id {
                VerseBridge.pendingJobID = ""
                VerseBridge.pendingInsertionJobID = ""
                VerseBridge.statusText = ""
            }
        }
        let result = try await localEngine.transcribe(url: url, model: selection.model, language: selection.language)
        let output = await TranscriptDelivery.prepare(id: id, text: result.text, language: result.language)
        try Task.checkCancellation()
        let filename = try library.keepAudio(url, id: pending.recordingID ?? id, existingName: pending.localAudioName)
        let now = ISO8601DateFormatter().string(from: Date())
        let item = Transcription(id: id, filename: pending.filename ?? url.lastPathComponent, state: "completed", model: selection.model,
                                 language: selection.language, detectedLanguage: result.language, text: result.text,
                                 durationSeconds: result.duration, error: nil, createdAt: now, updatedAt: now,
                                 origin: origin, engine: "on-device", localAudioName: filename,
                                 recordingID: pending.recordingID, customPrompt: selection.customPrompt).applying(output)
        let updated = [item] + items.filter { $0.id != id }
        try library.save(updated)
        items = updated
        if !pending.isRerun {
            VerseBridge.publishTranscriptionResult(id: id, statusCode: 200, state: item.state, text: item.text, error: nil)
        }
        try library.removePending(url)
        await notify(item)
        await updateActivity(recorder.isRecording ? "recording" : "ready")
        return item
    }

    @discardableResult
    func transcribeAgain(_ item: Transcription, selection: SpeechSelection) async throws -> Transcription {
        guard !isRerunning, !isUploading, !isStartingRecording, !recorder.isRecording else {
            throw SpeechFailure("Finish the current recording first.")
        }
        guard !deletingRecordingIDs.contains(item.recordingKey), items.contains(where: { $0.recordingKey == item.recordingKey }) else {
            throw SpeechFailure("This recording is no longer in your library.")
        }
        rerunningRecordingID = item.recordingKey
        defer { rerunningRecordingID = nil }
        if demo {
            let now = ISO8601DateFormatter().string(from: Date())
            let version = Transcription(id: "preview-\(UUID().uuidString)", filename: item.filename,
                                        state: "completed", model: selection.model, language: selection.language,
                                        detectedLanguage: item.detectedLanguage, text: item.originalText ?? item.text,
                                        durationSeconds: item.durationSeconds, error: nil, createdAt: now, updatedAt: now,
                                        origin: item.origin, engine: selection.onDevice ? "on-device" : nil,
                                        writingStyle: selection.style.rawValue, recordingID: item.recordingKey,
                                        customPrompt: selection.customPrompt)
            items.insert(version, at: 0)
            return version
        }
        try validateSelection(selection)
        let source = try await audio(for: item)
        try Task.checkCancellation()
        let name = try library.keepAudio(source, id: item.recordingKey, existingName: item.localAudioName)
        for index in items.indices where items[index].recordingKey == item.recordingKey && items[index].localAudioName == nil {
            items[index].localAudioName = name
        }
        try library.save(items)
        let pending = try library.prepareRerun(audio: source, item: item, selection: selection, localAudioName: name)
        defer { loadPendingAudio() }
        return try await upload(pending)
    }

    private func validateSelection(_ selection: SpeechSelection) throws {
        if selection.onDevice {
            guard localEngine.installedModelIDs.contains(selection.model) else {
                throw SpeechFailure("Download the \(selection.model) model in Settings before transcribing this recording.")
            }
        } else if VerseBridge.token.isEmpty {
            throw SpeechFailure("Add your device token in Settings first.")
        }
    }

    func audio(for item: Transcription) async throws -> URL {
        if let archived = try? library.audio(for: item) { return archived }
        if let archived = versions(for: item.id).compactMap({ try? library.audio(for: $0) }).first { return archived }
        if item.isLocal { return try library.audio(for: item) }
        return try await api.audio(item.id)
    }

    func delete(_ item: Transcription) async throws {
        let key = item.recordingKey
        guard rerunningRecordingID != key, !deletingRecordingIDs.contains(key) else {
            throw SpeechFailure("Wait for this transcription to finish.")
        }
        deletingRecordingIDs.insert(key)
        defer { deletingRecordingIDs.remove(key) }
        for version in versions(for: item.id) {
            if !demo, !version.isLocal { try await api.delete(version.id) }
            VerseBridge.invalidateTranscription(version.id)
            items.removeAll { $0.id == version.id }
            if VerseBridge.pendingJobID == version.id {
                VerseBridge.pendingJobID = ""
                VerseBridge.statusText = ""
            }
            if keyboardJobID == version.id { keyboardJobID = "" }
            if VerseBridge.transcriptID == version.id {
                VerseBridge.transcriptID = ""
                VerseBridge.transcriptText = ""
            }
            if !demo {
                try library.save(items)
                try library.deleteAudio(for: version, retaining: items)
            }
        }
        for url in pendingAudio where library.pendingTranscription(for: url)?.recordingID == key { try discardPending(url) }
    }

    private func tick() {
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
                    perform { try await self.toggleRecording(origin: .keyboard) }
                } else if action == "stop", recorder.isRecording {
                    perform { try await self.finishRecording() }
                }
            }
        }
        if Date().timeIntervalSince(lastPoll) >= 2,
           items.contains(where: \.isPending) || (!VerseBridge.pendingJobID.isEmpty && !VerseBridge.pendingJobID.hasPrefix("local-")) {
            lastPoll = Date()
            perform { try await self.refresh() }
        }
    }

    private func notify(_ item: Transcription) async {
        guard let body = item.completionNotificationBody(
            enabled: UserDefaults.standard.bool(forKey: "verse.completionNotifications"),
            appIsActive: UIApplication.shared.applicationState == .active
        ) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Transcription ready"
        content.body = body
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: item.id, content: content, trigger: nil))
    }

    private func loadPendingAudio() {
        guard !recorder.isRecording else { return }
        pendingAudio = library.pendingAudio()
    }

    func discardPending(_ url: URL) throws {
        try library.removePending(url)
        VerseBridge.removeProcessingState(for: TranscriptionLibrary.localID(for: url))
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
