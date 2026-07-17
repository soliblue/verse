import XCTest

@MainActor
final class VerseSmokeUITests: XCTestCase {
    func testLaunchesAsAQuietPagedReader() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["verse-reader"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["app-menu"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["reader-save"].exists)
        XCTAssertTrue(app.buttons["reader-actions"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["verse-floating-tabs"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["verse-mark"].exists)
        app.buttons["app-menu"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Articles"].tap()

        let first = app.descendants(matching: .any)["reader-story-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        assertHittable(first)

        app.descendants(matching: .any)["verse-reader"].swipeUp()

        let second = app.descendants(matching: .any)["reader-story-2"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        assertHittable(second)
    }

    func testStoryKeepsSupportingDetailsOnDemand() {
        let app = XCUIApplication()
        app.launch()

        let first = app.descendants(matching: .any)["reader-story-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        first.tap()

        XCTAssertTrue(app.descendants(matching: .any)["story-detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists)
        XCTAssertTrue(app.buttons["story-save"].exists)
        app.buttons["story-actions"].tap()
        XCTAssertTrue(app.buttons["Story details"].waitForExistence(timeout: 5))
        app.buttons["Story details"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["story-info"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["story-original"].waitForExistence(timeout: 5)
        )
        app.buttons["Done"].tap()

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["app-menu"].waitForExistence(timeout: 5))
    }

    func testNavigationLivesInThePixelMenu() {
        executionTimeAllowance = 90
        let app = XCUIApplication()
        app.launch()

        openTab("Library", app: app)
        XCTAssertTrue(app.descendants(matching: .any)["library-screen"].waitForExistence(timeout: 5))

        openTab("Settings", app: app)
        XCTAssertTrue(app.descendants(matching: .any)["settings-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Server URL"].exists)
        XCTAssertTrue(app.staticTexts["Prompts"].exists)
        XCTAssertFalse(app.buttons["Back"].exists)
        XCTAssertFalse(app.buttons["More"].exists)
        app.buttons["Topics"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["topics-markdown-editor"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["topics-save"].exists)
        app.buttons["topics-close"].tap()

        openTab("Articles", app: app)
        XCTAssertTrue(app.descendants(matching: .any)["verse-reader"].waitForExistence(timeout: 5))
    }

    func testCalendarAndPlacesAreDirectDestinations() {
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

        openTab("Places", app: app)
        XCTAssertTrue(app.descendants(matching: .any)["places-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UdK Sound Studies"].waitForExistence(timeout: 5))
    }

    func testKeyboardDismissesBySwipeAndTapAway() {
        let app = XCUIApplication()
        app.launch()

        openTab("Settings", app: app)
        app.buttons["Topics"].tap()
        let editor = app.textViews["topics-markdown-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let editorState = app.staticTexts["topics-editor-state"]
        XCTAssertTrue(editorState.waitForExistence(timeout: 5))

        editor.tap()
        assertValue("focused", for: editorState)
        editor.swipeDown()
        assertValue("unfocused", for: editorState)

        editor.tap()
        assertValue("focused", for: editorState)
        editorState.tap()
        assertValue("unfocused", for: editorState)
    }

    private func openTab(_ title: String, app: XCUIApplication) {
        let menu = app.buttons["app-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let tab = app.buttons["app-menu-\(title)"]
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

    private func assertDisappears(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    private func assertValue(_ value: String, for element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
