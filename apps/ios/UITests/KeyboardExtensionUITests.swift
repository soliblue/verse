import XCTest

@MainActor
final class KeyboardExtensionUITests: XCTestCase {
    func testInstalledExtensionSwitchesFromTheSystemKeyboard() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["VERSE_REAL_KEYBOARD_UI_TEST"] == "1", "Opt-in test for a disposable simulator")
        #if !targetEnvironment(simulator)
        throw XCTSkip("This test changes keyboard configuration on a disposable simulator only")
        #endif
        executionTimeAllowance = 120
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--system-keyboard-ui-testing"]
        app.launch()
        let field = app.textViews["keyboard-preview-text"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
        field.typeText("Keep this text.")
        let state = app.staticTexts["keyboard-fixture-state"]
        XCTAssertTrue(state.label.contains("root=nil"))
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        settings.launch()
        try tapSettingsRow("General", in: settings)
        try tapSettingsRow("Keyboard", in: settings)
        try tapSettingsRow("Keyboards", in: settings)
        var addedVerse = false
        defer {
            if addedVerse { removeVerseKeyboard(from: settings) }
        }
        if !settings.staticTexts["Verse"].firstMatch.exists {
            try tapSettingsRow("Add New Keyboard", in: settings, prefix: true)
            try tapSettingsRow("Verse", in: settings)
            addedVerse = true
            guard settings.staticTexts["Verse"].firstMatch.waitForExistence(timeout: 5) else {
                capture("real-extension-unavailable")
                throw XCTSkip("Settings did not register the bundled Verse keyboard")
            }
        }
        app.activate()
        field.tap()
        let root = element("keyboard-content", in: app)
        capture("real-extension-before-switch")
        try switchToVerse(in: app)
        assertExtension(in: app, field: field)
        capture("real-extension-first-presentation")
        for attempt in 1...2 {
            try nextKeyboardButton(in: app).tap()
            XCTAssertTrue(root.waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.keyboards.firstMatch.exists)
            XCTAssertEqual(field.value as? String, "Keep this text.")
            capture("real-extension-system-return-\(attempt)")
            try switchToVerse(in: app)
            assertExtension(in: app, field: field)
            capture("real-extension-reswitch-\(attempt)")
        }
        XCTAssertTrue(state.label.contains("root=nil"))
    }

    private func tapSettingsRow(_ label: String, in settings: XCUIApplication, prefix: Bool = false) throws {
        let row = prefix
            ? settings.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
            : settings.staticTexts[label].firstMatch
        for _ in 0..<4 {
            if row.waitForExistence(timeout: 1), row.isHittable {
                row.tap()
                return
            }
            settings.swipeUp()
        }
        capture("real-extension-settings-precondition")
        throw XCTSkip("Settings row unavailable: \(label)")
    }

    private func switchToVerse(in app: XCUIApplication) throws {
        let root = element("keyboard-content", in: app)
        for _ in 0..<6 {
            if root.waitForExistence(timeout: 0.5) { return }
            try nextKeyboardButton(in: app).tap()
        }
        XCTAssertTrue(root.waitForExistence(timeout: 5), "The enabled Verse extension did not appear")
    }

    private func nextKeyboardButton(in app: XCUIApplication) throws -> XCUIElement {
        let own = element("keyboard-voice-next-keyboard", in: app)
        if own.exists, own.isHittable { return own }
        let matches = app.buttons.matching(NSPredicate(format: "label IN %@", ["Next keyboard", "Next Keyboard", "Change keyboard", "Switch keyboard"]))
        if let next = matches.allElementsBoundByIndex.first(where: { $0.isHittable }) { return next }
        capture("real-extension-system-globe-unavailable")
        throw XCTSkip("The simulator did not expose a keyboard switch control")
    }

    private func assertExtension(in app: XCUIApplication, field: XCUIElement) {
        let root = element("keyboard-content", in: app)
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            root.exists && abs(root.frame.height - 260) <= 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed)
        let activation = element("keyboard-open-dictation", in: app)
        XCTAssertTrue(activation.waitForExistence(timeout: 5))
        XCTAssertTrue(activation.isHittable)
        XCTAssertEqual(activation.label, "Activate dictation")
        XCTAssertEqual(root.frame.minY, field.frame.maxY + 16, accuracy: 6)
        XCTAssertTrue(root.frame.contains(activation.frame))
        XCTAssertTrue(element("keyboard-voice-panel", in: app).exists)
        XCTAssertFalse(element("keyboard-typing-surface", in: app).exists)
        XCTAssertEqual(field.value as? String, "Keep this text.")
    }

    private func removeVerseKeyboard(from settings: XCUIApplication) {
        settings.activate()
        let row = settings.staticTexts["Verse"].firstMatch
        guard row.exists, row.isHittable else { return }
        row.swipeLeft()
        let delete = settings.buttons["Delete"].firstMatch
        if delete.exists, delete.isHittable { delete.tap() }
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
