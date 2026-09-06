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
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--typing-keyboard-ui-testing", "--keyboard-cold-ui-testing"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["keyboard-open-dictation"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(key("q", in: app).exists)
        XCTAssertFalse(app.buttons["keyboard-record"].exists)
        screenshot("keyboard-cold-controller")
    }

    func testActualKeyboardControllerLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--typing-keyboard-ui-testing"]
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
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--typing-keyboard-ui-testing", "--keyboard-dark-ui-testing"]
        app.launch()
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 8))
        screenshot("keyboard-dark-controller")
    }

    func testKeyboardTypingReachesHostField() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--typing-keyboard-ui-testing"]
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
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--typing-keyboard-ui-testing"]
        app.launch()
        XCTAssertTrue(key("q", in: app).waitForExistence(timeout: 8))
        let start = key("q", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = key("w", in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertEqual(app.textViews["keyboard-preview-text"].value as? String, "w")
    }

    func testPressedCharacterPreviewFixture() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--typing-keyboard-ui-testing", "--keyboard-popup-ui-testing"]
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
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing", "--typing-keyboard-ui-testing", "--keyboard-wave-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Stop recording"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Synthetic waveform · 10 Hz levels"].exists)
        XCTAssertFalse(app.buttons["Transcription language"].isEnabled)
        XCTAssertFalse(app.buttons["Transcription model"].isEnabled)
        screenshot("keyboard-wave-synthetic-10hz")
    }

    func testVoicePanelIsTheDefaultInputMode() {
        let app = launchVoicePanel()
        assertVoicePanel(in: app)
        let record = app.buttons["keyboard-record"]
        XCTAssertTrue(record.waitForExistence(timeout: 8))
        XCTAssertEqual(record.label, "Record")
        XCTAssertTrue(record.isEnabled)
        let panel = element("keyboard-voice-panel", in: app)
        let toolbar = element("keyboard-toolbar", in: app)
        XCTAssertGreaterThanOrEqual(record.frame.width, 160)
        XCTAssertEqual(record.frame.midX, panel.frame.midX, accuracy: 1)
        XCTAssertGreaterThan(record.frame.minY, toolbar.frame.maxY)
        XCTAssertFalse(element("keyboard-open-dictation", in: app).exists)
        XCTAssertFalse(app.staticTexts["keyboard-recording-duration"].exists)
        screenshot("voice-panel-ready")
    }

    func testVoicePanelSwitchesFromSystemKeyboard() {
        assertRepeatedKeyboardSwitches()
        screenshot("voice-panel-controller-switch-light")
    }

    func testDarkVoicePanelSwitchesFromSystemKeyboard() {
        assertRepeatedKeyboardSwitches(["--keyboard-dark-ui-testing", "--keyboard-cold-ui-testing"])
        screenshot("voice-panel-controller-switch-dark")
    }

    func testColdVoicePanelOffersAppActivation() {
        let app = launchVoicePanel(["--keyboard-cold-ui-testing"])
        assertVoicePanel(in: app)
        let activate = element("keyboard-open-dictation", in: app)
        XCTAssertTrue(activate.waitForExistence(timeout: 8))
        XCTAssertEqual(activate.label, "Activate dictation")
        XCTAssertTrue(activate.isHittable)
        XCTAssertGreaterThanOrEqual(activate.frame.width, 160)
        XCTAssertEqual(activate.frame.midX, element("keyboard-voice-panel", in: app).frame.midX, accuracy: 1)
        XCTAssertFalse(app.buttons["keyboard-record"].exists)
        screenshot("voice-panel-cold")
    }

    func testRecordingVoicePanelShowsWaveformAndStop() {
        let app = launchVoicePanel(["--keyboard-wave-ui-testing"])
        assertVoicePanel(in: app)
        let stop = app.buttons["Stop recording"]
        XCTAssertTrue(stop.waitForExistence(timeout: 8))
        let duration = app.staticTexts["keyboard-recording-duration"]
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        XCTAssertTrue(duration.label.contains(":"))
        let toolbar = element("keyboard-toolbar", in: app)
        XCTAssertEqual(stop.frame.height, 44, accuracy: 1)
        XCTAssertEqual(stop.frame.minY, toolbar.frame.minY + 8, accuracy: 1)
        XCTAssertEqual(toolbar.frame.maxX - stop.frame.maxX, 16, accuracy: 1)
        XCTAssertGreaterThan(duration.frame.minY, toolbar.frame.maxY)
        XCTAssertFalse(app.buttons["Transcription language"].isEnabled)
        XCTAssertFalse(app.buttons["Transcription model"].isEnabled)
        XCTAssertFalse(element("keyboard-open-dictation", in: app).exists)
        screenshot("voice-panel-recording")
    }

    func testDarkVoicePanelKeepsTheSameLayout() {
        let app = launchVoicePanel(["--keyboard-dark-ui-testing"])
        assertVoicePanel(in: app)
        let record = app.buttons["keyboard-record"]
        XCTAssertTrue(record.waitForExistence(timeout: 8))
        XCTAssertEqual(record.frame.midX, element("keyboard-voice-panel", in: app).frame.midX, accuracy: 1)
        screenshot("voice-panel-dark")
    }

    func testProcessingVoicePanelUsesAnIconOnly() {
        let app = launchVoicePanel(["--keyboard-processing-ui-testing"])
        assertVoicePanel(in: app)
        let processing = app.buttons["Transcribing"]
        XCTAssertTrue(processing.waitForExistence(timeout: 8))
        XCTAssertFalse(processing.isEnabled)
        XCTAssertFalse(app.buttons["Transcription language"].isEnabled)
        XCTAssertFalse(app.buttons["Transcription model"].isEnabled)
        XCTAssertFalse(app.staticTexts["Transcribing"].exists)
        XCTAssertFalse(app.staticTexts["keyboard-recording-duration"].exists)
        XCTAssertFalse(element("keyboard-open-dictation", in: app).exists)
        XCTAssertEqual(element("keyboard-toolbar", in: app).frame.maxX - processing.frame.maxX, 16, accuracy: 1)
        screenshot("voice-panel-processing")
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

    private func launchVoicePanel(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--keyboard-ui-testing"] + arguments
        app.launch()
        return app
    }

    private func assertRepeatedKeyboardSwitches(_ arguments: [String] = []) {
        let app = launchVoicePanel(["--keyboard-switch-ui-testing"] + arguments)
        let field = app.textViews["keyboard-preview-text"]
        let content = element("keyboard-content", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        XCTAssertEqual(field.value as? String, "Keep this text.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(content.exists)
        for showVerse in [true, false, true] {
            app.buttons["keyboard-fixture-switch"].tap()
            if showVerse {
                let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    content.exists && abs(content.frame.height - 260) <= 1
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed)
                assertVoicePanel(in: app)
                XCTAssertEqual(content.frame.minY, field.frame.maxY + 16, accuracy: 6)
            } else {
                XCTAssertTrue(content.waitForNonExistence(timeout: 8))
                XCTAssertTrue(app.keyboards.firstMatch.exists)
            }
            XCTAssertEqual(field.value as? String, "Keep this text.")
        }
    }

    private func assertVoicePanel(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let panel = element("keyboard-voice-panel", in: app)
        XCTAssertTrue(panel.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertFalse(key("q", in: app).exists, file: file, line: line)
        XCTAssertFalse(key("space", in: app).exists, file: file, line: line)
        XCTAssertFalse(element("keyboard-typing-surface", in: app).exists, file: file, line: line)
        XCTAssertFalse(app.staticTexts["Speak"].exists, file: file, line: line)
        XCTAssertFalse(app.staticTexts["Uploading"].exists, file: file, line: line)
        let content = element("keyboard-content", in: app)
        let toolbar = element("keyboard-toolbar", in: app)
        XCTAssertEqual(content.frame.height, 260, accuracy: 1, file: file, line: line)
        XCTAssertEqual(toolbar.frame.height, 52, accuracy: 1, file: file, line: line)
        XCTAssertEqual(toolbar.frame.minY, content.frame.minY, accuracy: 1, file: file, line: line)
        let language = app.buttons["Transcription language"]
        let model = app.buttons["Transcription model"]
        XCTAssertTrue(language.exists, file: file, line: line)
        XCTAssertTrue(model.exists, file: file, line: line)
        XCTAssertEqual(language.frame.width, 44, accuracy: 1, file: file, line: line)
        XCTAssertEqual(language.frame.height, 44, accuracy: 1, file: file, line: line)
        XCTAssertEqual(language.frame.minX - content.frame.minX, 16, accuracy: 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(model.frame.minX, language.frame.maxX, file: file, line: line)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
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
