import Foundation
import XCTest
@testable import Verse

@MainActor
final class CalendarLinkTests: XCTestCase {
    func testRepositoryCanReleaseAfterStoringALink() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let repository = CalendarRepository(defaults: defaults)
        repository.recordLink(
            occurrenceID: "event-occurrence",
            eventIdentifier: "calendar-event",
            fingerprint: "current"
        )
    }

    func testLocalLinkPreventsDuplicateExportState() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = CalendarLinkStore(defaults: defaults)
        store.record(
            occurrenceID: "event-occurrence",
            eventIdentifier: "calendar-event",
            fingerprint: "current"
        )

        let reopened = CalendarLinkStore(defaults: defaults)
        XCTAssertEqual(
            reopened.state(
                occurrenceID: "event-occurrence",
                fingerprint: "current",
                isCancelled: false
            ),
            .linked
        )
    }

    func testUnresolvedLinkStillPreventsDuplicateExportState() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = CalendarLinkStore(defaults: defaults)
        store.record(
            occurrenceID: "event-occurrence",
            eventIdentifier: nil,
            fingerprint: "current"
        )

        let reopened = CalendarLinkStore(defaults: defaults)
        XCTAssertEqual(
            reopened.state(
                occurrenceID: "event-occurrence",
                fingerprint: "current",
                isCancelled: false
            ),
            .linked
        )
    }
}
