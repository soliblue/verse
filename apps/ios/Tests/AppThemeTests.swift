import SwiftUI
import XCTest
@testable import Verse

@MainActor
final class AppThemeTests: XCTestCase {
    func testMissingPreferenceDefaultsToLight() {
        let previous = UserDefaults.standard.string(forKey: "appTheme")
        defer { restore(previous) }

        UserDefaults.standard.removeObject(forKey: "appTheme")

        XCTAssertEqual(AppTheme.persisted, .light)
        XCTAssertEqual(AppTheme.persisted.colorScheme, .light)
    }

    func testPreferencePersists() {
        let previous = UserDefaults.standard.string(forKey: "appTheme")
        defer { restore(previous) }

        AppTheme.persisted = .dark

        XCTAssertEqual(AppTheme.persisted, .dark)
        XCTAssertEqual(AppTheme.persisted.colorScheme, .dark)
        XCTAssertNil(AppTheme.system.colorScheme)
    }

    private func restore(_ value: String?) {
        if let value {
            UserDefaults.standard.set(value, forKey: "appTheme")
        } else {
            UserDefaults.standard.removeObject(forKey: "appTheme")
        }
    }
}
