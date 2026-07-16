import Foundation
import XCTest
@testable import Verse

@MainActor
final class ExploreContractTests: XCTestCase {
    func testBundledExploreIsFiniteAndConsistent() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-explore", withExtension: "json"))
        let payload = try JSONDecoder().decode(ExplorePayload.self, from: Data(contentsOf: url))

        XCTAssertEqual(payload.timezone, "Europe/Berlin")
        XCTAssertLessThanOrEqual(payload.featuredEvents.count, 12)
        XCTAssertLessThanOrEqual(payload.attendedEvents?.count ?? 0, 12)
        XCTAssertFalse(payload.featuredEvents.isEmpty)
        XCTAssertEqual(
            Set(payload.featuredEvents.map(\.id)).count,
            payload.featuredEvents.count
        )
        XCTAssertTrue(
            payload.featuredEvents.allSatisfy {
                $0.occurrence.state != .ended && $0.occurrence.state != .cancelled
            }
        )
        XCTAssertEqual(Set(payload.calendar.map(\.id)).count, payload.calendar.count)
        XCTAssertTrue(payload.featuredEvents.contains { $0.occurrence.isFree })
        XCTAssertTrue(
            payload.calendar.allSatisfy { occurrence in
                payload.allEvents.contains {
                    $0.id == occurrence.eventID && $0.occurrence.id == occurrence.id
                }
            }
        )
        XCTAssertTrue(
            payload.venues.allSatisfy { venue in
                guard let nextEventID = venue.nextEventID else { return true }
                return payload.allEvents.contains { $0.occurrence.id == nextEventID }
            }
        )
    }

    func testStoryRelatedEventsRemainOptional() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-edition", withExtension: "json"))
        let edition = try JSONDecoder().decode(EditionPayload.self, from: Data(contentsOf: url))

        XCTAssertTrue(edition.items.allSatisfy { $0.relatedEventIDs == nil })
    }

    func testAttendedHistoryDecodesAndRemainsPartOfEventLookup() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-explore", withExtension: "json"))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        var events = try XCTUnwrap(object["events"] as? [[String: Any]])
        var attended = events.removeFirst()
        var occurrence = try XCTUnwrap(attended["occurrence"] as? [String: Any])
        occurrence["state"] = "ended"
        attended["occurrence"] = occurrence
        object["events"] = events
        object["attended_events"] = [attended]

        let payload = try JSONDecoder().decode(
            ExplorePayload.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(payload.attendedEvents?.count, 1)
        XCTAssertTrue(payload.allEvents.contains { $0.occurrence.id == occurrence["id"] as? String })
    }

    func testStoryDecodesRelatedEventIdentifiers() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-edition", withExtension: "json"))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        var items = try XCTUnwrap(object["items"] as? [[String: Any]])
        items[0]["related_event_ids"] = ["udk-sounds-rundgang-2026-07-17"]
        object["items"] = items

        let edition = try JSONDecoder().decode(
            EditionPayload.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(
            edition.items[0].relatedEventIDs,
            ["udk-sounds-rundgang-2026-07-17"]
        )
    }

    func testBerlinFormattingDoesNotFollowDeviceTimezone() {
        XCTAssertEqual(EventDateFormatting.day("2026-07-16T23:30:00Z"), "Fri, Jul 17")
        XCTAssertEqual(EventDateFormatting.time("2026-07-16T23:30:00Z"), "01:30")
        XCTAssertEqual(
            EventDateFormatting.horizonDate("2026-07-16").map(EventDateFormatting.dayKey),
            "2026-07-16"
        )
    }

    func testDistanceBandsArePresentedAsWords() {
        let venue = Venue(
            id: "venue",
            name: "Venue",
            address: nil,
            latitude: nil,
            longitude: nil,
            neighborhood: nil,
            officialURL: URL(string: "https://example.com")!,
            whyWatched: "Reason",
            distanceBand: "short_ride",
            watchState: .watch,
            nextEventID: nil,
            calendarURL: nil
        )

        XCTAssertEqual(venue.distanceLabel, "Short Ride")
    }

    func testSoldOutAndCancelledOccurrencesAreNeverAttendable() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-explore", withExtension: "json"))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        var events = try XCTUnwrap(object["events"] as? [[String: Any]])
        var occurrence = try XCTUnwrap(events[0]["occurrence"] as? [String: Any])
        occurrence["sold_out"] = true
        events[0]["occurrence"] = occurrence
        object["events"] = events
        var payload = try JSONDecoder().decode(
            ExplorePayload.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(payload.events[0].occurrence.bookingLabel, "Sold out")
        XCTAssertFalse(payload.events[0].occurrence.isAttendable(at: .distantPast))

        events = try XCTUnwrap(object["events"] as? [[String: Any]])
        occurrence = try XCTUnwrap(events[0]["occurrence"] as? [String: Any])
        occurrence["sold_out"] = false
        occurrence["state"] = "cancelled"
        events[0]["occurrence"] = occurrence
        object["events"] = events
        payload = try JSONDecoder().decode(
            ExplorePayload.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(payload.events[0].occurrence.bookingLabel, "Cancelled")
        XCTAssertFalse(payload.events[0].occurrence.isAttendable(at: .distantPast))
    }
}
