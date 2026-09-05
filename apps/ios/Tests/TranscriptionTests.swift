import AVFoundation
import XCTest
@testable import Verse

@MainActor
final class TranscriptionTests: XCTestCase {
    func testServerPayloadDecodes() throws {
        let data = Data("""
        {"id":"abc","filename":"voice.m4a","state":"completed","model":"small","language":"auto","detected_language":"en","text":"Hello","duration_seconds":2.5,"error":null,"created_at":"2026-09-05T09:00:00+00:00","updated_at":"2026-09-05T09:00:00+00:00"}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let item = try decoder.decode(Transcription.self, from: data)
        XCTAssertEqual(item.text, "Hello")
        XCTAssertEqual(item.detectedLanguage, "en")
        XCTAssertFalse(item.isPending)
        XCTAssertGreaterThan(item.date.timeIntervalSince1970, 0)
    }

    func testCaptureProducesPlayableCompressedAudio() throws {
        let writer = CaptureWriter()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000))
        buffer.frameLength = 48_000
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for frame in 0..<48_000 { samples[frame] = Float(sin(Double(frame) * 440 * 2 * .pi / 48_000)) * 0.2 }
        try writer.begin(url: url, format: format)
        writer.append(buffer)
        try writer.finish()
        let file = try AVAudioFile(forReading: url)
        XCTAssertGreaterThan(file.length, 40_000)
        XCTAssertLessThan(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max, 50_000)
    }
}
