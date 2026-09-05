import XCTest

@MainActor
final class VerseSmokeUITests: XCTestCase {
    override func tearDown() {
        let state = XCUIApplication().staticTexts["keyboard-fixture-state"]
        if state.exists {
            let attachment = XCTAttachment(string: state.label)
            attachment.name = "keyboard-fixture-layout"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        super.tearDown()
    }

    func testColdKeyboardLinkLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--keyboard-cold-ui-testing"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["keyboard-open-dictation"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(key("q", in: app).exists)
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
        XCTAssertEqual(key("delete", in: app).label, "Delete")
        XCTAssertEqual(key("return", in: app).label, "Return")
        XCTAssertFalse(app.buttons["Open Verse"].exists)
        XCTAssertEqual(key("q", in: app).label, "q")
        let content = app.descendants(matching: .any)["keyboard-content"].firstMatch
        let toolbar = app.descendants(matching: .any)["keyboard-toolbar"].firstMatch
        XCTAssertTrue(content.exists)
        XCTAssertTrue(toolbar.exists)
        XCTAssertEqual(toolbar.frame.height, 44, accuracy: 1)
        XCTAssertLessThanOrEqual(abs(content.frame.minY - app.textViews["keyboard-preview-text"].frame.maxY - 16), 6)
        XCTAssertLessThanOrEqual(abs(toolbar.frame.minY - content.frame.minY), 6)
        XCTAssertLessThanOrEqual(key("q", in: app).frame.minY - toolbar.frame.maxY, 14)
        XCTAssertGreaterThanOrEqual(key("q", in: app).frame.height, 36)
        XCTAssertLessThanOrEqual(key("q", in: app).frame.height, 54)
        XCTAssertGreaterThanOrEqual(app.buttons["Transcription language"].frame.minX - content.frame.minX, 10)
        XCTAssertGreaterThanOrEqual(content.frame.maxX - app.buttons["keyboard-record"].frame.maxX, 10)
        key("shift", in: app).tap()
        XCTAssertEqual(key("q", in: app).label, "Q")
        XCTAssertEqual(key("mode", in: app).label, "Numbers")
        key("mode", in: app).tap()
        XCTAssertTrue(key("1", in: app).exists)
        XCTAssertEqual(key("shift", in: app).label, "More symbols")
        key("shift", in: app).tap()
        XCTAssertTrue(key("[", in: app).exists)
        XCTAssertEqual(key("mode", in: app).label, "Letters")
        key("mode", in: app).tap()
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
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 8))
        screenshot("keyboard-dark-controller")
    }

    func testKeyboardTypingReachesHostField() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing"]
        app.launch()
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 8))
        let field = app.textViews["keyboard-preview-text"]
        for character in "hello" {
            key(String(character), in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.01)
        }
        key("space", in: app).tap()
        for character in "verse" { key(String(character), in: app).tap() }
        XCTAssertEqual(field.value as? String, "hello verse")
        key("delete", in: app).tap()
        XCTAssertEqual(field.value as? String, "hello vers")
        key("e", in: app).tap()
        key("return", in: app).tap()
        XCTAssertEqual(field.value as? String, "hello verse\n")
        screenshot("keyboard-host-typing")
    }

    func testKeyboardSlideCorrectsBeforeRelease() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing"]
        app.launch()
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 8))
        let start = key("q", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = key("w", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertEqual(app.textViews["keyboard-preview-text"].value as? String, "w")
    }

    func testPressedCharacterPreviewFixture() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--keyboard-popup-ui-testing"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["keyboard-key-preview"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(app.textViews["keyboard-preview-text"].value as? String, "")
        screenshot("keyboard-pressed-key-fixture")
    }

    func testSystemKeyboardReferenceLight() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--system-keyboard-ui-testing"]
        app.launch()
        XCTAssertTrue(app.textViews["keyboard-preview-text"].waitForExistence(timeout: 8))
        app.textViews["keyboard-preview-text"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
        screenshot("keyboard-system-light-reference")
    }

    func testSyntheticWaveformFixture() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--keyboard-wave-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Stop recording"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Synthetic waveform · 10 Hz levels"].exists)
        XCTAssertFalse(app.buttons["Transcription language"].isEnabled)
        XCTAssertFalse(app.buttons["Transcription model"].isEnabled)
        screenshot("keyboard-wave-synthetic-10hz")
    }

    func testSystemKeyboardReferenceDark() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--system-keyboard-ui-testing", "--keyboard-dark-ui-testing"]
        app.launch()
        XCTAssertTrue(app.textViews["keyboard-preview-text"].waitForExistence(timeout: 8))
        app.textViews["keyboard-preview-text"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
        screenshot("keyboard-system-dark-reference")
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

    private func key(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["keyboard-key-\(name)"].firstMatch
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
