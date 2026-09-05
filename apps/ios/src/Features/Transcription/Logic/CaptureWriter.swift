import AVFoundation
import Foundation

nonisolated final class CaptureWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var failure: Error?

    func begin(url: URL, format: AVAudioFormat) throws {
        let output = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderBitRateKey: 64_000
        ])
        lock.lock()
        file = output
        failure = nil
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let file, failure == nil else { return }
        if case .failure(let error) = Result(catching: { try file.write(from: buffer) }) { failure = error }
    }

    func finish() throws {
        lock.lock()
        let error = failure
        file = nil
        failure = nil
        lock.unlock()
        if let error { throw error }
    }
}
