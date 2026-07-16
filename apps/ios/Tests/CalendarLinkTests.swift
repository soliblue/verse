import Foundation
import SwiftData
import XCTest
@testable import Verse

@MainActor
final class CalendarLinkTests: XCTestCase {
    func testLocalLinkPreventsDuplicateExportState() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedCalendarLink.self,
            configurations: configuration
        )
        let item = try event()
        let fingerprint = [
            item.title,
            item.occurrence.startAt,
            item.occurrence.endAt ?? "",
            item.venue.address ?? item.venue.name,
            item.occurrence.state.rawValue,
        ].joined(separator: "|")
        container.mainContext.insert(
            CachedCalendarLink(
                occurrenceID: item.occurrence.id,
                eventIdentifier: "calendar-event",
                fingerprint: fingerprint
            )
        )
        try container.mainContext.save()

        let repository = CalendarRepository(context: container.mainContext)
        XCTAssertEqual(repository.state(for: item), .linked)
    }

    func testUnresolvedLinkStillPreventsDuplicateExportState() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedCalendarLink.self,
            configurations: configuration
        )
        let item = try event()
        let fingerprint = [
            item.title,
            item.occurrence.startAt,
            item.occurrence.endAt ?? "",
            item.venue.address ?? item.venue.name,
            item.occurrence.state.rawValue,
        ].joined(separator: "|")
        container.mainContext.insert(
            CachedCalendarLink(
                occurrenceID: item.occurrence.id,
                eventIdentifier: nil,
                fingerprint: fingerprint
            )
        )
        try container.mainContext.save()

        let repository = CalendarRepository(context: container.mainContext)
        XCTAssertEqual(repository.state(for: item), .linked)
    }

    private func event() throws -> EventItem {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-explore", withExtension: "json"))
        return try XCTUnwrap(
            JSONDecoder().decode(ExplorePayload.self, from: Data(contentsOf: url)).featuredEvents.first
        )
    }
}
