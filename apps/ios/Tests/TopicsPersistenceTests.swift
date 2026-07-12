import Foundation
import SwiftData
import XCTest
@testable import Morrow

@MainActor
final class TopicsPersistenceTests: XCTestCase {
    func testOfflineTopicEditSurvivesReloadAndRemainsPending() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CachedTopics.self, configurations: configuration)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let server = ServerConfiguration(defaults: defaults)
        let repository = TopicsRepository(
            context: container.mainContext,
            api: APIClient(configuration: server)
        )
        let topic = Topic(
            id: "spatial-audio",
            name: "Spatial audio",
            kind: .interest,
            description: "Listen for practical spatial techniques.",
            isEnabled: true,
            position: 1
        )

        let didSync = await repository.save(TopicList(topics: [topic]))

        XCTAssertFalse(didSync)
        let reopened = TopicsRepository(
            context: ModelContext(container),
            api: APIClient(configuration: server)
        )
        let reloaded = await reopened.load()
        XCTAssertEqual(reloaded?.topics, [topic])
    }
}
