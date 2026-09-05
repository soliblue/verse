import AVFoundation
import Accelerate
import Foundation

nonisolated final class CaptureWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var failure: Error?
    private var level = 0.0

    var audioLevel: Double {
        lock.lock()
        defer { lock.unlock() }
        return level
    }

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
        level = 0
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let file, failure == nil else { return }
        level = Self.normalizedLevel(buffer)
        if case .failure(let error) = Result(catching: { try file.write(from: buffer) }) {
            failure = error
            level = 0
        }
    }

    func finish() throws {
        lock.lock()
        let error = failure
        file = nil
        failure = nil
        level = 0
        lock.unlock()
        if let error { throw error }
    }

    static func normalizedLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard buffer.frameLength > 0, let samples = buffer.floatChannelData?[0] else { return 0 }
        var rms: Float = 0
        vDSP_rmsqv(samples, vDSP_Stride(buffer.stride), &rms, vDSP_Length(buffer.frameLength))
        guard rms.isFinite, rms > 0 else { return 0 }
        return min(1, max(0, (Double(20 * log10(rms)) + 50) / 50))
    }
}
