import XCTest

@MainActor
final class SpeechSettingsUITests: XCTestCase {
    func testLocalModelsDefaultToMediumWithoutDownloading() {
        let app = settings(availability: "available")
        XCTAssertTrue(app.segmentedControls.buttons["iPhone"].isSelected)
        XCTAssertTrue(app.buttons["Download Medium"].exists || app.buttons["download-local-model"].exists)
        XCTAssertTrue(app.buttons["local-model-picker"].exists)
        screenshot("settings-local-medium")
    }

    func testAvailableWritingOffersCustomPrompt() {
        let app = settings(availability: "available")
        let picker = app.buttons["writing-style-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        app.buttons["Custom"].firstMatch.tap()
        let prompt = app.textFields["custom-writing-prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        prompt.tap()
        prompt.typeText("Keep it short and friendly.")
        XCTAssertEqual(prompt.value as? String, "Keep it short and friendly.")
        screenshot("settings-custom-writing")
    }

    func testDisabledAppleIntelligenceHidesStyles() {
        let app = settings(availability: "appleIntelligenceNotEnabled")
        XCTAssertTrue(app.staticTexts["Apple Intelligence is off"].exists)
        XCTAssertFalse(app.buttons["writing-style-picker"].exists)
        XCTAssertFalse(app.textFields["custom-writing-prompt"].exists)
        XCTAssertTrue(app.buttons["apple-intelligence-settings"].exists)
        screenshot("settings-intelligence-disabled")
    }

    func testOlderIOSHidesStylesAndExplainsRequirement() {
        let app = settings(availability: "requiresUpdate")
        XCTAssertTrue(app.staticTexts["iOS update needed"].exists)
        XCTAssertFalse(app.buttons["writing-style-picker"].exists)
        XCTAssertTrue(app.staticTexts["Writing styles need iOS 26 or later. Transcription still works."].exists)
        screenshot("settings-ios-update")
    }

    func testModelNotReadyHidesStyles() {
        let app = settings(availability: "modelNotReady")
        XCTAssertTrue(app.staticTexts["Apple Intelligence is getting ready"].exists)
        XCTAssertFalse(app.buttons["writing-style-picker"].exists)
        screenshot("settings-intelligence-downloading")
    }

    private func settings(availability: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--writing-availability=" + availability]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        return app
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
