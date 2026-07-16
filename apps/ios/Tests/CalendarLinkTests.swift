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

    func testChangedAndCancelledEventsRequireExplicitReview() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let store = CalendarLinkStore(defaults: defaults)
        store.record(
            occurrenceID: "event-occurrence",
            eventIdentifier: "calendar-event",
            fingerprint: "original"
        )

        XCTAssertEqual(
            store.state(
                occurrenceID: "event-occurrence",
                fingerprint: "changed",
                isCancelled: false
            ),
            .updated
        )
        XCTAssertEqual(
            store.state(
                occurrenceID: "event-occurrence",
                fingerprint: "changed",
                isCancelled: true
            ),
            .cancelled
        )
        let endedStore = CalendarLinkStore(
            defaults: try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        )
        XCTAssertEqual(
            endedStore.state(
                occurrenceID: "ended-occurrence",
                fingerprint: "current",
                isCancelled: false,
                isEnded: true
            ),
            .ended
        )
    }
}
