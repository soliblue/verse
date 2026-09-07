import XCTest

@MainActor
final class TranscriptMenuUITests: XCTestCase {
    func testMenuListsVersionsAndDirectRegenerationChoices() {
        let app = launch(["--versions-ui-testing", "--installed-models=medium,turbo"])
        let picker = app.buttons["transcript-version-picker"]
        XCTAssertTrue(picker.label.contains("AUTO"))
        picker.tap()
        XCTAssertTrue(app.buttons["transcript-version-preview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["transcript-version-preview"].label.contains("AUTO"))
        XCTAssertTrue(app.buttons["regenerate-model-local.medium"].exists)
        XCTAssertTrue(app.buttons["regenerate-model-local.turbo"].exists)
        XCTAssertTrue(app.buttons["regenerate-model-cloud.small"].exists)
        XCTAssertTrue(app.buttons["regenerate-model-cloud.medium"].exists)
        XCTAssertTrue(app.buttons["regenerate-model-cloud.large-v3"].exists)
        XCTAssertTrue(app.buttons["transcript-language-picker"].exists)
        XCTAssertFalse(app.buttons["Transcribe again…"].exists)
        XCTAssertFalse(app.buttons["transcribe-again"].exists)
        screenshot("receipt-unified-transcript-menu")
    }

    func testLanguageChangesOnlyTheNewVersion() {
        let app = launch(["--installed-models=medium,turbo"])
        let picker = app.buttons["transcript-version-picker"]
        picker.tap()
        app.buttons["transcript-language-picker"].tap()
        let german = app.buttons["regeneration-language-de"].exists
            ? app.buttons["regeneration-language-de"] : app.buttons["German"].firstMatch
        XCTAssertTrue(german.waitForExistence(timeout: 3))
        german.tap()
        let turbo = app.buttons["regenerate-model-local.turbo"]
        XCTAssertTrue(turbo.waitForExistence(timeout: 3))
        turbo.tap()
        let regenerated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Local Turbo", "DE"), object: picker
        )
        XCTAssertEqual(XCTWaiter.wait(for: [regenerated], timeout: 5), .completed)
        XCTAssertTrue(app.descendants(matching: .any)["transcript-metadata"].firstMatch.label.contains("DE"))
        picker.tap()
        let original = app.buttons["transcript-version-preview"]
        XCTAssertTrue(original.waitForExistence(timeout: 3))
        XCTAssertTrue(original.label.contains("AUTO"))
        screenshot("receipt-regenerated-language-versions")
        original.tap()
        XCTAssertTrue(picker.label.contains("AUTO"))
    }

    func testMissingModelDownloadsAndRegeneratesDirectly() {
        let app = launch(["--installed-models=medium"])
        app.buttons["transcript-version-picker"].tap()
        let tiny = model("local.tiny", in: app)
        XCTAssertTrue(tiny.exists)
        tiny.tap()
        let picker = app.buttons["transcript-version-picker"]
        let downloaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Local Tiny"), object: picker)
        XCTAssertEqual(XCTWaiter.wait(for: [downloaded], timeout: 8), .completed)
        XCTAssertFalse(app.navigationBars["Model"].exists)
        picker.tap()
        XCTAssertTrue(app.buttons["transcript-version-preview"].waitForExistence(timeout: 3))
        screenshot("receipt-downloaded-and-regenerated")
    }

    func testCancellingDownloadPreservesTheSelectedVersion() {
        let app = launch(["--installed-models=medium", "--hold-model-download"])
        let picker = app.buttons["transcript-version-picker"]
        let original = picker.label
        picker.tap()
        model("local.tiny", in: app).tap()
        let cancel = app.buttons["Cancel model download"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["transcript-model-download"].firstMatch.exists)
        screenshot("receipt-regeneration-download")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertEqual(picker.label, original)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    private func model(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["regenerate-model-" + id]
        for _ in 0..<4 where !button.isHittable { app.swipeUp() }
        return button
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        let recording = app.buttons["recording-preview"]
        XCTAssertTrue(recording.waitForExistence(timeout: 8))
        recording.tap()
        XCTAssertTrue(app.buttons["transcript-version-picker"].waitForExistence(timeout: 5))
        return app
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
