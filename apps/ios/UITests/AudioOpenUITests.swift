import AVFoundation
import XCTest

@MainActor
final class AudioOpenUITests: XCTestCase {
    func testFileOpenDismissesSettingsAndKeepsLocalSelectionForRetry() throws {
        let audio = try audioFile()
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["speech-model-picker"].waitForExistence(timeout: 5))
        app.open(audio)
        assertMissingLocalModel(in: app)
        XCTAssertFalse(app.buttons["speech-model-picker"].exists)
        screenshot("audio-open-local-model-preserved")
        app.alerts.buttons["OK"].tap()
        app.buttons["Settings"].tap()
        app.buttons["speech-model-picker"].tap()
        app.buttons["model-choice-cloud.large-v3"].tap()
        XCTAssertTrue(app.buttons["speech-model-picker"].label.contains("Cloud Large v3"))
        app.buttons["Done"].tap()
        app.swipeUp()
        let retry = app.buttons["Retry recording"].firstMatch
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()
        assertMissingLocalModel(in: app)
        screenshot("audio-open-retry-keeps-original-model")
    }

    func testFileOpenCanLaunchVerseFromNotRunning() throws {
        let audio = try audioFile()
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.terminate()
        app.open(audio)
        assertMissingLocalModel(in: app)
        screenshot("audio-open-cold-launch")
    }

    private func assertMissingLocalModel(in app: XCUIApplication) {
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.alerts.staticTexts["Download the medium model in Settings before transcribing this recording."].exists)
        XCTAssertFalse(app.buttons["Transcribe on server"].exists)
    }

    private func audioFile() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Voice note.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_600))
        buffer.frameLength = 1_600
        buffer.floatChannelData?[0].initialize(repeating: 0, count: 1_600)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
