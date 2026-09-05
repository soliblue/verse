import AVFoundation
import Foundation
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

    func testMeterPublishesFasterThanFourHertzOffMainThread() throws {
        let (writer, url) = try recordingWriter()
        defer {
            try? writer.finish()
            try? FileManager.default.removeItem(at: url)
        }
        let updates = expectation(description: "Five audio levels")
        updates.expectedFulfillmentCount = 5
        updates.assertForOverFulfill = false
        let stopped = expectation(description: "Final zero")
        let samples = Samples()
        let publisher = VoiceRecorder.LevelPublisher(writer: writer) { level in
            samples.append(level)
            if level > 0 { updates.fulfill() }
            else { stopped.fulfill() }
        }
        publisher.start()
        wait(for: [updates], timeout: 2)
        publisher.stop()
        wait(for: [stopped], timeout: 2)
        let values = samples.values
        let active = values.filter { $0.level > 0 }
        XCTAssertGreaterThanOrEqual(active.count, 5)
        if active.count >= 5 {
            let elapsed = active[4].time - active[0].time
            XCTAssertLessThan(elapsed, 0.65)
            let evidence = XCTAttachment(string: "Five real RMS samples in \(elapsed) seconds. Measured rate: \(4 / elapsed) Hz. Main-thread publications: \(values.filter(\.mainThread).count).")
            evidence.name = "audio-meter-cadence"
            evidence.lifetime = .keepAlways
            add(evidence)
        }
        XCTAssertTrue(values.allSatisfy { !$0.mainThread })
        XCTAssertEqual(values.last?.level, 0)
    }

    func testMeterStopOrdersZeroAfterInFlightPublication() throws {
        let (writer, url) = try recordingWriter()
        defer {
            try? writer.finish()
            try? FileManager.default.removeItem(at: url)
        }
        let publishing = expectation(description: "Publication in flight")
        let stopped = expectation(description: "Final zero after publication")
        let stale = expectation(description: "No publication after stop")
        stale.isInverted = true
        let release = DispatchSemaphore(value: 0)
        let samples = Samples()
        let publisher = VoiceRecorder.LevelPublisher(writer: writer) { level in
            let values = samples.append(level)
            if values.count == 1 {
                publishing.fulfill()
                _ = release.wait(timeout: .now() + 3)
            } else if level == 0 {
                stopped.fulfill()
            } else if values.contains(where: { $0.level == 0 }) {
                stale.fulfill()
            }
        }
        publisher.start()
        wait(for: [publishing], timeout: 2)
        publisher.stop()
        release.signal()
        wait(for: [stopped], timeout: 2)
        wait(for: [stale], timeout: 0.3)
        XCTAssertEqual(samples.values.last?.level, 0)
    }

    private func recordingWriter() throws -> (CaptureWriter, URL) {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256))
        buffer.frameLength = 256
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for index in 0..<256 { samples[index] = 0.5 }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("meter-\(UUID().uuidString).m4a")
        let writer = CaptureWriter()
        try writer.begin(url: url, format: format)
        writer.append(buffer)
        return (writer, url)
    }

    nonisolated private final class Samples: @unchecked Sendable {
        nonisolated struct Sample: Sendable {
            let level: Double
            let time: TimeInterval
            let mainThread: Bool
        }

        private let lock = NSLock()
        private var stored: [Sample] = []

        var values: [Sample] {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }

        @discardableResult
        func append(_ level: Double) -> [Sample] {
            lock.lock()
            defer { lock.unlock() }
            stored.append(Sample(level: level, time: ProcessInfo.processInfo.systemUptime, mainThread: Thread.isMainThread))
            return stored
        }
    }
}
