import XCTest

@MainActor
final class VerseSmokeUITests: XCTestCase {
    func testLaunchesAsAFullArticleSwipeReader() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["verse-reader"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.buttons.count, 2)
        XCTAssertTrue(app.buttons["reader-like"].exists)
        XCTAssertTrue(app.buttons["reader-dislike"].exists)
        XCTAssertFalse(app.buttons["reader-save"].exists)
        XCTAssertFalse(app.buttons["reader-actions"].exists)
        XCTAssertFalse(app.buttons["app-menu"].exists)

        let first = app.descendants(matching: .any)["reader-story-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        assertHittable(first)
        XCTAssertTrue(app.descendants(matching: .any)["story-body"].exists)

        app.descendants(matching: .any)["verse-reader"].swipeLeft()

        let second = app.descendants(matching: .any)["reader-story-2"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        assertHittable(second)
    }

    func testReaderOnlyShowsLikeAndDislikeActions() {
        let app = XCUIApplication()
        app.launch()

        let first = app.descendants(matching: .any)["reader-story-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["story-body"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons.firstMatch.exists)
        XCTAssertTrue(app.buttons["reader-like"].exists)
        XCTAssertTrue(app.buttons["reader-dislike"].exists)
        XCTAssertFalse(app.buttons["reader-save"].exists)
        XCTAssertFalse(app.buttons["reader-actions"].exists)
    }

    func testBottomTabsOnlyShowArticlesAndCalendar() {
        executionTimeAllowance = 90
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Articles"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
        XCTAssertFalse(app.tabBars.buttons["Places"].exists)
        XCTAssertFalse(app.tabBars.buttons["Library"].exists)
        XCTAssertFalse(app.tabBars.buttons["Settings"].exists)
    }

    func testCalendarIsADirectDestination() {
        executionTimeAllowance = 90
        let app = XCUIApplication()
        app.launch()

        openTab("Calendar", app: app)
        XCTAssertTrue(app.descendants(matching: .any)["calendar-screen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Previous week"].exists)
        XCTAssertFalse(app.buttons["Next week"].exists)

        let july16 = app.buttons["calendar-day-2026-07-16"]
        XCTAssertTrue(july16.waitForExistence(timeout: 5))
        july16.tap()
        XCTAssertTrue(app.staticTexts["Berlin Beats: GiGi FM"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Add to Calendar"].exists)

        app.buttons["calendar-day-2026-07-18"].tap()
        XCTAssertTrue(app.staticTexts["DayDreamLab by Transmission"].waitForExistence(timeout: 5))
        app.staticTexts["DayDreamLab by Transmission"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["event-detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["event-actions"].exists)
        app.navigationBars.buttons.firstMatch.tap()
    }

    private func openTab(_ title: String, app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
    }

    private func assertHittable(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

}
