import AVFoundation
import Observation

@MainActor
@Observable
final class VoiceRecorder {
    private let engine = AVAudioEngine()
    private let writer = CaptureWriter()
    private var fileURL: URL?
    private(set) var isActive = false
    private(set) var isRecording = false
    private(set) var startedAt = Date()

    func activate() async throws {
        guard !isActive else { return }
        let permission = await AVAudioApplication.requestRecordPermission()
        guard permission else { throw SpeechFailure("Allow microphone access in iPhone Settings to record.") }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            try? session.setActive(false)
            throw SpeechFailure("No microphone is available.")
        }
        let writer = writer
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in writer.append(buffer) }
        let result = Result { try engine.start() }
        if case .failure(let error) = result {
            input.removeTap(onBus: 0)
            try? session.setActive(false)
            throw error
        }
        isActive = true
    }

    func begin() throws {
        guard isActive, !isRecording else { return }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PendingAudio", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Recording-\(UUID().uuidString).m4a")
        try writer.begin(url: url, format: engine.inputNode.outputFormat(forBus: 0))
        fileURL = url
        startedAt = Date()
        isRecording = true
    }

    func finish() throws -> URL? {
        guard isRecording else { return nil }
        isRecording = false
        let url = fileURL
        fileURL = nil
        try writer.finish()
        return url
    }

    func deactivate() {
        engine.stop()
        if isActive { engine.inputNode.removeTap(onBus: 0) }
        isActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
