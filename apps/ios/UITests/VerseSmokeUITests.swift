import XCTest

@MainActor
final class VerseSmokeUITests: XCTestCase {
    func testLaunchesAndPagesThroughBundledEdition() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["verse-reader"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.descendants(matching: .any)["verse-mark"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["verse-floating-tabs"].waitForExistence(timeout: 5)
        )
        for tab in ["Today", "Library", "Topics", "Settings"] {
            XCTAssertTrue(app.buttons[tab].exists)
        }

        let first = app.descendants(matching: .any)["reader-story-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        assertHittable(first)

        app.descendants(matching: .any)["verse-reader"].swipeUp()

        let second = app.descendants(matching: .any)["reader-story-2"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        assertHittable(second)
    }

    func testStoryOpensWithoutPersistentDock() {
        let app = XCUIApplication()
        app.launch()

        let first = app.descendants(matching: .any)["reader-story-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        first.tap()

        XCTAssertTrue(app.descendants(matching: .any)["story-detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["story-back"].exists)
        let dock = app.descendants(matching: .any)["verse-floating-tabs"]
        let dockGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: dock
        )
        XCTAssertEqual(XCTWaiter.wait(for: [dockGone], timeout: 2), .completed)

        app.buttons["story-back"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["verse-floating-tabs"].waitForExistence(timeout: 5)
        )
    }

    func testSettingsOpensFromFloatingTabs() {
        let app = XCUIApplication()
        app.launch()

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        settings.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Server URL"].exists)
    }

    func testLibraryAndTopicsOpenFromFloatingTabs() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 8))
        app.buttons["Library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))

        app.buttons["Topics"].tap()
        XCTAssertTrue(app.navigationBars["Topics"].waitForExistence(timeout: 5))

        app.buttons["Today"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["verse-reader"].waitForExistence(timeout: 5))
    }

    private func assertHittable(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
