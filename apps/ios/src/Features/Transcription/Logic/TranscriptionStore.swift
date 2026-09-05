import AVFoundation
import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class TranscriptionStore {
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

    init() {
        if VerseBridge.token.isEmpty {
            VerseBridge.token = KeychainStore.value(for: "device-secret")
        }
        VerseBridge.sessionExpiresAt = 0
        VerseBridge.isRecording = false
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
            for await _ in NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification) {
                self?.perform { [weak self] in try await self?.endSession() }
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
                error = failure.localizedDescription
                VerseBridge.errorText = failure.localizedDescription
                VerseBridge.statusText = ""
                loadPendingAudio()
            }
        }
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
            } else { VerseBridge.errorText = item.error ?? "Transcription failed. Try again in Verse." }
            keyboardJobID = ""
            VerseBridge.pendingJobID = ""
        }
    }

    func checkConnection() async throws {
        guard !demo else { return }
        models = try await api.configuration().models
        try await refresh()
    }

    func toggleRecording() async throws {
        guard !isStartingRecording else { return }
        guard isConfigured else { throw SpeechFailure("Add your device token in Settings first.") }
        if recorder.isRecording {
            try await finishRecording()
        } else {
            isStartingRecording = true
            defer { isStartingRecording = false }
            try await recorder.activate()
            try recorder.begin()
            VerseBridge.isRecording = true
            VerseBridge.errorText = ""
        }
    }

    func activateKeyboard() async throws {
        guard !isStartingRecording else { return }
        guard isConfigured else { throw SpeechFailure("Add your device token in Settings first.") }
        isStartingRecording = true
        defer { isStartingRecording = false }
        try await recorder.activate()
        keyboardExpiresAt = Date().addingTimeInterval(300)
        VerseBridge.sessionExpiresAt = keyboardExpiresAt!.timeIntervalSince1970
        VerseBridge.sessionHeartbeatAt = Date().timeIntervalSince1970
        VerseBridge.errorText = ""
        VerseBridge.statusText = "Ready"
    }

    func endSession() async throws {
        keyboardExpiresAt = nil
        VerseBridge.sessionExpiresAt = 0
        VerseBridge.sessionHeartbeatAt = 0
        let result = Result { try recorder.finish() }
        recorder.deactivate()
        VerseBridge.isRecording = false
        let url = try result.get()
        if let url { try await upload(url, keyboard: true) }
    }

    func finishRecording() async throws {
        let result = Result { try recorder.finish() }
        VerseBridge.isRecording = false
        if keyboardExpiresAt == nil { recorder.deactivate() }
        let url = try result.get()
        if let url { try await upload(url, keyboard: keyboardExpiresAt != nil) }
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
        let item = try await api.upload(url)
        items.insert(item, at: 0)
        VerseBridge.statusText = "Transcribing…"
        VerseBridge.pendingJobID = item.id
        if keyboard {
            keyboardJobID = item.id
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
                if action == "start", !recorder.isRecording, !isUploading {
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
}
