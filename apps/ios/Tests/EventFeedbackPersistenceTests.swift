import Foundation
import SwiftData
import XCTest
@testable import Verse

@MainActor
final class EventFeedbackPersistenceTests: XCTestCase {
    func testLovedEventPersistsAndQueuesFeedbackOffline() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedEventFeedbackState.self,
            PendingMutation.self,
            configurations: configuration
        )
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let server = ServerConfiguration(defaults: defaults)
        let repository = EventFeedbackRepository(
            context: container.mainContext,
            api: APIClient(configuration: server)
        )

        _ = await repository.update(
            eventID: "sputnik-open-screening",
            occurrenceID: "sputnik-open-screening-july",
            kind: .loved
        )

        let reopened = EventFeedbackRepository(
            context: ModelContext(container),
            api: APIClient(configuration: server)
        )
        let state = reopened.state(
            eventID: "sputnik-open-screening",
            occurrenceID: "sputnik-open-screening-july"
        )
        XCTAssertTrue(state.loved)
        XCTAssertTrue(state.attended)
        XCTAssertEqual(
            try container.mainContext.fetchCount(FetchDescriptor<PendingMutation>()),
            1
        )
    }

    func testEventFeedbackUsesTransportKeys() throws {
        let data = try JSONEncoder().encode(
            EventFeedback(
                eventID: "event-1",
                occurrenceID: "occurrence-1",
                kind: .moreFromVenue,
                value: true
            )
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["event_id"] as? String, "event-1")
        XCTAssertEqual(object["occurrence_id"] as? String, "occurrence-1")
        XCTAssertEqual(object["kind"] as? String, "more_from_venue")
        XCTAssertEqual(object["value"] as? Bool, true)
    }
}
