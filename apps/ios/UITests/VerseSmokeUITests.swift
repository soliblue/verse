import XCTest

@MainActor
final class VerseSmokeUITests: XCTestCase {
    func testColdKeyboardLinkLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--keyboard-cold-ui-testing"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["keyboard-open-dictation"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["q"].exists)
        XCTAssertFalse(app.buttons["keyboard-record"].exists)
        screenshot("keyboard-cold-controller")
    }

    func testActualKeyboardControllerLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["keyboard-record"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Transcription language"].exists)
        XCTAssertTrue(app.buttons["Transcription model"].exists)
        XCTAssertTrue(app.buttons["Delete"].exists)
        XCTAssertTrue(app.buttons["Return"].exists)
        XCTAssertFalse(app.buttons["Open Verse"].exists)
        XCTAssertTrue(app.buttons["q"].exists)
        app.buttons["Shift"].tap()
        XCTAssertTrue(app.buttons["Q"].exists)
        app.buttons["Numbers"].tap()
        XCTAssertTrue(app.buttons["1"].exists)
        app.buttons["More symbols"].tap()
        XCTAssertTrue(app.buttons["["].exists)
        app.buttons["Letters"].tap()
        screenshot("keyboard-controller")
    }

    func testTranscriptionHub() {
        let app = launch()
        XCTAssertTrue(app.buttons["Record"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Speak"].exists)
        XCTAssertFalse(app.staticTexts["Uploading"].exists)
        XCTAssertFalse(app.staticTexts["Starting"].exists)
        XCTAssertTrue(app.buttons["Import audio"].exists)
        XCTAssertTrue(app.buttons["Activate keyboard"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Articles"].exists)
        XCTAssertFalse(app.staticTexts["Calendar"].exists)
        screenshot("hub")
    }

    func testDarkKeyboardLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--keyboard-dark-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["q"].waitForExistence(timeout: 8))
        screenshot("keyboard-dark-controller")
    }

    func testTranscriptCanBeReadAndCopied() {
        let app = launch()
        let recording = app.staticTexts["Hey, I'm on my way. Let's meet outside in ten minutes."]
        XCTAssertTrue(recording.waitForExistence(timeout: 8))
        recording.tap()
        XCTAssertTrue(app.staticTexts["transcript-text"].waitForExistence(timeout: 5))
        app.buttons["Copy transcript"].tap()
        XCTAssertTrue(app.buttons["Copied"].exists)
        XCTAssertTrue(app.buttons["Share transcript"].exists)
        screenshot("transcript")
    }

    func testSettingsDismissWithoutExtraNavigation() {
        let app = launch()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.secureTextFields["Device token"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
        XCTAssertFalse(app.staticTexts["Appearance"].exists)
        screenshot("settings")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Record"].waitForExistence(timeout: 5))
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
