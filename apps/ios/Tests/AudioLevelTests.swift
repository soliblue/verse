import AVFoundation
import XCTest
@testable import Verse

@MainActor
final class AudioLevelTests: XCTestCase {
    func testMeterTracksVolumeAndClampsSilence() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256))
        buffer.frameLength = 256
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for index in 0..<256 { samples[index] = 0 }
        XCTAssertEqual(CaptureWriter.normalizedLevel(buffer), 0)
        for index in 0..<256 { samples[index] = 0.01 }
        let quiet = CaptureWriter.normalizedLevel(buffer)
        for index in 0..<256 { samples[index] = 0.5 }
        let loud = CaptureWriter.normalizedLevel(buffer)
        XCTAssertGreaterThan(quiet, 0)
        XCTAssertGreaterThan(loud, quiet)
        XCTAssertLessThanOrEqual(loud, 1)
        for index in 0..<256 { samples[index] = 2 }
        XCTAssertEqual(CaptureWriter.normalizedLevel(buffer), 1)
    }

    func testIdleAudioDoesNotUpdateMeter() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256))
        buffer.frameLength = 256
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for index in 0..<256 { samples[index] = 0.5 }
        let writer = CaptureWriter()
        writer.append(buffer)
        XCTAssertEqual(writer.audioLevel, 0)
    }
}
