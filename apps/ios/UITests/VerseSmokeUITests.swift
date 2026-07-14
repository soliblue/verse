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
        app.buttons["Today"].tap()

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
        XCTAssertTrue(app.buttons["story-back"].exists)
        XCTAssertTrue(app.buttons["story-save"].exists)
        app.buttons["story-actions"].tap()
        XCTAssertTrue(app.buttons["Story details"].waitForExistence(timeout: 5))
        app.buttons["Story details"].tap()
        XCTAssertTrue(app.navigationBars["Story details"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["story-original"].waitForExistence(timeout: 5)
        )
        app.buttons["Done"].tap()

        app.buttons["story-back"].tap()
        XCTAssertTrue(app.buttons["app-menu"].waitForExistence(timeout: 5))
    }

    func testNavigationLivesInThePixelMenu() {
        let app = XCUIApplication()
        app.launch()

        openTab("Library", app: app)
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))

        openTab("Topics", app: app)
        XCTAssertTrue(app.navigationBars["Topics"].waitForExistence(timeout: 5))

        openTab("Settings", app: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Server URL"].exists)

        openTab("Today", app: app)
        XCTAssertTrue(app.descendants(matching: .any)["verse-reader"].waitForExistence(timeout: 5))
    }

    func testAppearanceDefaultsToLightAndSwitchesImmediately() {
        let app = XCUIApplication()
        app.launch()

        openTab("Settings", app: app)
        assertResolvedTheme("light", app: app)

        selectAppearance("Dark", app: app)
        assertResolvedTheme("dark", app: app)

        selectAppearance("Light", app: app)
        assertResolvedTheme("light", app: app)
    }

    private func openTab(_ title: String, app: XCUIApplication) {
        let menu = app.buttons["app-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let tab = app.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
    }

    private func selectAppearance(_ title: String, app: XCUIApplication) {
        let picker = app.descendants(matching: .any)["appearance-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let option = app.buttons[title]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
    }

    private func assertResolvedTheme(_ theme: String, app: XCUIApplication) {
        let marker = app.staticTexts["resolved-theme"]
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", theme),
            object: marker
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    private func assertHittable(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
