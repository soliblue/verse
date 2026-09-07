import XCTest

@MainActor
final class TranscriptionReceiptUITests: XCTestCase {
    func testTranscriptOpensAsAnExpandableHalfSheet() {
        let app = launch()
        let recording = app.buttons["recording-preview"]
        XCTAssertTrue(recording.waitForExistence(timeout: 8))
        XCTAssertLessThanOrEqual(recording.frame.minX, 26)
        XCTAssertLessThanOrEqual(app.frame.maxX - recording.frame.maxX, 26)
        recording.tap()
        let text = app.staticTexts["transcript-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        let sheet = app.descendants(matching: .any)["transcript-sheet"].firstMatch
        XCTAssertTrue(sheet.exists)
        XCTAssertGreaterThan(sheet.frame.minY, app.frame.height * 0.35)
        XCTAssertLessThan(sheet.frame.minY, app.frame.height * 0.65)
        XCTAssertTrue(app.buttons["transcript-version-picker"].exists)
        XCTAssertFalse(app.buttons["transcribe-again"].exists)
        XCTAssertTrue(app.buttons["Play recording"].exists)
        XCTAssertFalse(app.navigationBars.buttons["Back"].exists)
        screenshot("quiet-receipt-transcript-half-sheet")
        let start = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertLessThan(sheet.frame.minY, app.frame.height * 0.25)
        screenshot("quiet-receipt-transcript-expanded")
    }

    func testToolbarStaysPinnedWhileHistoryScrolls() {
        let app = launch(["--history-ui-testing"])
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        let top = settings.frame.minY
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(settings.isHittable)
        XCTAssertEqual(settings.frame.minY, top, accuracy: 1)
        XCTAssertTrue(app.buttons["Import audio"].isHittable)
        screenshot("quiet-receipt-history-scrolled")
    }

    func testVersionsStayInOneRecordingAndCanSwitch() {
        let app = launch(["--versions-ui-testing"])
        let recording = app.buttons["recording-preview"]
        XCTAssertTrue(recording.waitForExistence(timeout: 8))
        XCTAssertTrue(recording.label.contains("2 versions"))
        recording.tap()
        let picker = app.buttons["transcript-version-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let original = app.buttons["transcript-version-preview"]
        XCTAssertTrue(original.waitForExistence(timeout: 3))
        original.tap()
        XCTAssertEqual(app.staticTexts["transcript-text"].label, "Hey, I'm on my way. Let's meet outside in ten minutes.")
        dismissTranscript(in: app)
        XCTAssertTrue(recording.label.contains("Let's meet outside"))
        XCTAssertTrue(recording.label.contains("Local Medium"))
        XCTAssertTrue(recording.label.contains("AUTO"))
        recording.tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.label.contains("Local Medium"))
        picker.tap()
        let alternate = app.buttons["transcript-version-preview-cloud-small"]
        XCTAssertTrue(alternate.waitForExistence(timeout: 3))
        alternate.tap()
        screenshot("quiet-receipt-transcript-alternate")
        dismissTranscript(in: app)
        XCTAssertTrue(recording.label.contains("Meet me outside"))
        XCTAssertTrue(recording.label.contains("Cloud Small"))
    }

    func testRedoAddsVersionWithoutChangingDefaultModel() {
        let app = launch(["--installed-models=medium,turbo"])
        app.buttons["recording-preview"].tap()
        app.buttons["transcript-version-picker"].tap()
        let turbo = app.buttons["regenerate-model-local.turbo"]
        XCTAssertTrue(turbo.waitForExistence(timeout: 5))
        turbo.tap()
        let picker = app.buttons["transcript-version-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.label.contains("Local Turbo"))
        picker.tap()
        XCTAssertTrue(app.buttons["transcript-version-preview"].exists)
        screenshot("quiet-receipt-transcript-versions")
        app.buttons["transcript-version-preview"].tap()
        dismissTranscript(in: app)
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["speech-model-picker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["speech-model-picker"].label.contains("Local Medium"))
    }

    func testSwipeLeftDeletesRecordingAndItsVersions() {
        let app = launch(["--versions-ui-testing"])
        let recording = app.buttons["recording-preview"]
        XCTAssertTrue(recording.waitForExistence(timeout: 8))
        recording.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: recording.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        screenshot("quiet-receipt-swipe-delete")
        delete.tap()
        XCTAssertTrue(app.staticTexts["Your recordings will appear here."].waitForExistence(timeout: 5))
        XCTAssertFalse(recording.exists)
        XCTAssertFalse(app.buttons["recording-preview-cloud-small"].exists)
    }

    func testHistoryRowsAreCompactAndHaveNoKeyboardShortcut() {
        let app = launch(["--history-ui-testing"])
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        app.swipeUp()
        app.swipeUp()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recording-preview-history-"))
            .allElementsBoundByIndex.filter { $0.isHittable }
        XCTAssertGreaterThanOrEqual(rows.count, 6)
        for row in rows {
            XCTAssertLessThanOrEqual(row.frame.height, 86)
            XCTAssertTrue(row.label.contains("AUTO"))
        }
        XCTAssertFalse(app.buttons["Activate keyboard"].exists)
        screenshot("quiet-receipt-compact-history")
    }

    private func dismissTranscript(in app: XCUIApplication) {
        let sheet = app.descendants(matching: .any)["transcript-sheet"].firstMatch
        sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
    }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
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
