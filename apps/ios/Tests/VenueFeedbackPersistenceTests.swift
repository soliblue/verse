import Foundation
import SwiftData
import XCTest
@testable import Verse

@MainActor
final class VenueFeedbackPersistenceTests: XCTestCase {
    func testVenueFeedbackUsesTransportKeysAndQueuesOffline() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: PendingMutation.self,
            configurations: configuration
        )
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let repository = VenueFeedbackRepository(
            context: container.mainContext,
            api: APIClient(configuration: ServerConfiguration(defaults: defaults))
        )

        await repository.update(venueID: "sputnik-kino", kind: .moreFromHere)

        let mutation = try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<PendingMutation>()).first
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: mutation.payload) as? [String: Any]
        )
        XCTAssertEqual(mutation.path, APIEndpoint.venueFeedback)
        XCTAssertEqual(object["venue_id"] as? String, "sputnik-kino")
        XCTAssertEqual(object["kind"] as? String, "more_from_here")
        XCTAssertEqual(object["value"] as? Bool, true)
    }
}
