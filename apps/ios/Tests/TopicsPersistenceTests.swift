import Foundation
import SwiftData
import XCTest
@testable import Verse

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
        let document = PreferencesDocument(
            markdown: "# Preferences\n\n## Spatial audio\n\nListen for practical spatial techniques.\n"
        )

        let result = await repository.save(document)

        guard case .pending = result else {
            return XCTFail("An offline save must remain pending")
        }
        let reopened = TopicsRepository(
            context: ModelContext(container),
            api: APIClient(configuration: server)
        )
        let reloaded = await reopened.load()
        XCTAssertEqual(reloaded, document)
    }
}
