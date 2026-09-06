import XCTest

@MainActor
final class SpeechSettingsUITests: XCTestCase {
    func testModelsShareOneListAndDefaultToLocalMedium() {
        let app = settings(availability: "available")
        XCTAssertTrue(app.buttons["speech-model-picker"].label.contains("Local Medium"))
        XCTAssertFalse(app.segmentedControls.firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Ready on this iPhone"].exists)
        app.buttons["speech-model-picker"].tap()
        let medium = app.buttons["model-choice-local.medium"]
        XCTAssertTrue(medium.waitForExistence(timeout: 5))
        XCTAssertEqual(medium.value as? String, "Not downloaded")
        XCTAssertTrue(app.buttons["model-choice-local.turbo"].exists)
        XCTAssertTrue(app.buttons["model-choice-cloud.medium"].exists)
        screenshot("quiet-receipt-model-list")
        app.buttons["model-choice-cloud.medium"].tap()
        XCTAssertTrue(app.buttons["speech-model-picker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["speech-model-picker"].label.contains("Cloud Medium"))
    }

    func testSelectingMissingLocalModelStartsDownloadInItsRow() {
        let app = settings(availability: "available", arguments: ["--hold-model-download"])
        app.buttons["speech-model-picker"].tap()
        app.buttons["model-choice-local.medium"].tap()
        let progress = app.descendants(matching: .any)["model-progress-local.medium"].firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["model-choice-local.medium"].value as? String, "Downloading")
        XCTAssertTrue(app.buttons["Cancel model download"].exists)
        screenshot("quiet-receipt-model-downloading")
        app.buttons["Cancel model download"].tap()
        let cancelled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Not downloaded"), object: app.buttons["model-choice-local.medium"])
        XCTAssertEqual(XCTWaiter.wait(for: [cancelled], timeout: 3), .completed)
    }

    func testAvailableWritingOffersCustomPromptAfterEnabling() {
        let app = settings(availability: "available")
        XCTAssertFalse(app.buttons["writing-style-picker"].exists)
        tapSwitch(app.switches["apple-intelligence-toggle"])
        let picker = app.buttons["writing-style-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        app.buttons["Custom"].firstMatch.tap()
        let prompt = app.textFields["custom-writing-prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        prompt.tap()
        prompt.typeText("Keep it short and friendly.")
        XCTAssertEqual(prompt.value as? String, "Keep it short and friendly.")
        screenshot("quiet-receipt-custom-writing")
    }

    func testDisabledAppleIntelligenceStaysOffAndHighlightsSetup() {
        let app = settings(availability: "appleIntelligenceNotEnabled")
        let toggle = app.switches["apple-intelligence-toggle"]
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.buttons["writing-style-picker"].exists)
        XCTAssertFalse(app.buttons["Open Settings"].exists)
        assertSetupPulse(toggle, helper: app.buttons["apple-intelligence-setup"])
        XCTAssertEqual(toggle.value as? String, "0")
        screenshot("quiet-receipt-intelligence-disabled")
    }

    func testKeyboardNeedsConfirmedSetupAndUsesSameFeedback() {
        let app = settings(availability: "appleIntelligenceNotEnabled")
        let toggle = app.switches["typing-keyboard-toggle"]
        if !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        assertSetupPulse(toggle, helper: app.buttons["typing-keyboard-setup"])
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.buttons["iPhone Settings"].exists)
        screenshot("quiet-receipt-keyboard-setup")
    }

    func testConfirmedKeyboardCanEnableOptionalTyping() {
        let app = settings(availability: "available", arguments: ["--keyboard-setup-confirmed"])
        let toggle = app.switches["typing-keyboard-toggle"]
        if !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        tapSwitch(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
    }

    func testOlderIOSHidesStylesAndExplainsRequirement() {
        let app = settings(availability: "requiresUpdate")
        XCTAssertEqual(app.switches["apple-intelligence-toggle"].value as? String, "0")
        XCTAssertFalse(app.buttons["writing-style-picker"].exists)
        XCTAssertTrue(app.buttons["apple-intelligence-setup"].label.contains("iOS 26"))
        screenshot("quiet-receipt-ios-update")
    }

    func testModelNotReadyHidesStyles() {
        let app = settings(availability: "modelNotReady")
        XCTAssertEqual(app.switches["apple-intelligence-toggle"].value as? String, "0")
        XCTAssertFalse(app.buttons["writing-style-picker"].exists)
        XCTAssertTrue(app.buttons["apple-intelligence-setup"].label.contains("not ready"))
    }

    private func assertSetupPulse(_ toggle: XCUIElement, helper: XCUIElement) {
        let before = (helper.value as? String ?? "").split(separator: ":")
        let previousStart = before.count == 4 ? Double(before[1]) ?? 0 : 0
        tapSwitch(toggle)
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            let value = (helper.value as? String ?? "").split(separator: ":")
            if value.count == 4, value[0] == "pulse",
               let start = Double(value[1]), let end = Double(value[2]),
               start > previousStart, end > start, value[3] == "0" {
                XCTAssertEqual(end - start, 1, accuracy: 0.4)
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("Setup instructions did not complete the one-second highlight")
    }

    private func tapSwitch(_ toggle: XCUIElement) {
        let nativeControl = toggle.switches.firstMatch
        if nativeControl.exists { nativeControl.tap() }
        else { toggle.tap() }
    }

    private func settings(availability: String, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--writing-availability=" + availability] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["speech-model-picker"].waitForExistence(timeout: 5))
        return app
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
