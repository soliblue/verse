import Foundation
import XCTest
@testable import Verse

@MainActor
final class CalendarLinkTests: XCTestCase {
    func testLocalLinkPreventsDuplicateExportState() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let item = try event()
        let fingerprint = [
            item.title,
            item.occurrence.startAt,
            item.occurrence.endAt ?? "",
            item.venue.address ?? item.venue.name,
            item.occurrence.state.rawValue,
        ].joined(separator: "|")
        let repository = CalendarRepository(defaults: defaults)
        repository.recordLink(
            occurrenceID: item.occurrence.id,
            eventIdentifier: "calendar-event",
            fingerprint: fingerprint
        )

        let reopened = CalendarRepository(defaults: defaults)
        XCTAssertEqual(reopened.state(for: item), .linked)
    }

    func testUnresolvedLinkStillPreventsDuplicateExportState() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let item = try event()
        let fingerprint = [
            item.title,
            item.occurrence.startAt,
            item.occurrence.endAt ?? "",
            item.venue.address ?? item.venue.name,
            item.occurrence.state.rawValue,
        ].joined(separator: "|")
        let repository = CalendarRepository(defaults: defaults)
        repository.recordLink(
            occurrenceID: item.occurrence.id,
            eventIdentifier: nil,
            fingerprint: fingerprint
        )

        let reopened = CalendarRepository(defaults: defaults)
        XCTAssertEqual(reopened.state(for: item), .linked)
    }

    private func event() throws -> EventItem {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-explore", withExtension: "json"))
        return try XCTUnwrap(
            JSONDecoder().decode(ExplorePayload.self, from: Data(contentsOf: url)).featuredEvents.first
        )
    }
}
