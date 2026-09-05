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
        for _ in 0..<10 { writer.append(buffer) }
        XCTAssertGreaterThan(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0, 32 * 1024)
        try writer.finish()
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatMPEG4AAC)
        XCTAssertGreaterThan(file.length, 450_000)
        XCTAssertLessThan(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max, 250_000)
    }

    func testRecordingUploadIdentifierSurvivesRetry() {
        let id = "ABCD1234-5678-4ABC-9123-123456789ABC"
        let url = URL(fileURLWithPath: "Recording-\(id).m4a")
        XCTAssertEqual(SpeechAPI.recordingIdentifier(for: url), "abcd123456784abc9123123456789abc")
        let restored = URL(fileURLWithPath: "PendingAudio/Recording-\(id).m4a")
        XCTAssertEqual(SpeechAPI.recordingIdentifier(for: restored), SpeechAPI.recordingIdentifier(for: url))
        XCTAssertNil(SpeechAPI.recordingIdentifier(for: URL(fileURLWithPath: "Imported.m4a")))
        XCTAssertNil(SpeechAPI.recordingIdentifier(for: URL(fileURLWithPath: "Recording-invalid.m4a")))
    }
}
