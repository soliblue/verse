import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class VoiceRecorder {
    private let engine = AVAudioEngine()
    private let writer: CaptureWriter
    private let meter: LevelPublisher
    private(set) var fileURL: URL?
    private(set) var isActive = false
    private(set) var isRecording = false
    private(set) var startedAt = Date()

    init() {
        let writer = CaptureWriter()
        self.writer = writer
        meter = LevelPublisher(writer: writer)
        meter.stop()
    }

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
        meter.start()
    }

    func finish() throws -> URL? {
        meter.stop()
        guard isRecording else { return nil }
        isRecording = false
        let url = fileURL
        fileURL = nil
        try writer.finish()
        return url
    }

    func deactivate() {
        meter.stop()
        engine.stop()
        if isActive { engine.inputNode.removeTap(onBus: 0) }
        isActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated final class LevelPublisher: @unchecked Sendable {
        private let queue = DispatchQueue(label: "soli.verse.audio-level", qos: .userInitiated)
        private let writer: CaptureWriter
        private let publish: @Sendable (Double) -> Void
        private var timer: DispatchSourceTimer?
        private var generation = 0

        init(writer: CaptureWriter, publish: @escaping @Sendable (Double) -> Void = { VerseBridge.publishAudioLevel($0) }) {
            self.writer = writer
            self.publish = publish
        }

        deinit { timer?.cancel() }

        func start() {
            queue.async { [self] in
                generation += 1
                let currentGeneration = generation
                timer?.cancel()
                let source = DispatchSource.makeTimerSource(queue: queue)
                source.setEventHandler { [weak self] in
                    guard let self, generation == currentGeneration else { return }
                    publish(writer.audioLevel)
                }
                source.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(10))
                timer = source
                source.resume()
            }
        }

        func stop() {
            queue.async { [self] in
                generation += 1
                timer?.cancel()
                timer = nil
                publish(0)
            }
        }
    }
}
