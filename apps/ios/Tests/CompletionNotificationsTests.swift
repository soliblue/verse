import UserNotifications
import XCTest
@testable import Verse

@MainActor
final class CompletionNotificationsTests: XCTestCase {
    func testFirstImportRequestsSystemPermission() {
        XCTAssertEqual(CompletionNotifications.action(preference: nil, authorization: .notDetermined), .request)
    }

    func testPreviouslyGrantedPermissionEnablesCompletionNotifications() {
        for status: UNAuthorizationStatus in [.authorized, .provisional, .ephemeral] {
            XCTAssertEqual(CompletionNotifications.action(preference: nil, authorization: status), .enable)
            XCTAssertEqual(CompletionNotifications.action(preference: true, authorization: status), .none)
        }
    }

    func testExplicitOptOutIsPreserved() {
        for status: UNAuthorizationStatus in [.notDetermined, .denied, .authorized, .provisional, .ephemeral] {
            XCTAssertEqual(CompletionNotifications.action(preference: false, authorization: status), .none)
        }
    }

    func testDeniedPermissionDoesNotPromptAgain() {
        XCTAssertEqual(CompletionNotifications.action(preference: nil, authorization: .denied), .none)
        XCTAssertEqual(CompletionNotifications.action(preference: true, authorization: .denied), .none)
    }
}
