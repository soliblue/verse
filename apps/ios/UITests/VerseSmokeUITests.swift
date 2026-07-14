import XCTest

@MainActor
final class VerseSmokeUITests: XCTestCase {
    func testLaunchesWithBundledEditionAndAllTabs() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["verse-mark"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Library"].exists)
        XCTAssertTrue(app.tabBars.buttons["Topics"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    func testSettingsOpens() {
        let app = XCUIApplication()
        app.launch()
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Server URL"].exists)
    }
}
