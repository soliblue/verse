import Foundation
import SwiftData
import XCTest
@testable import Morrow

@MainActor
final class FeedbackPersistenceTests: XCTestCase {
    func testLocalFeedbackSurvivesReopeningStaleEditionStory() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedStoryState.self,
            PendingMutation.self,
            configurations: configuration
        )
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let server = ServerConfiguration(defaults: defaults)
        let repository = FeedbackRepository(
            context: container.mainContext,
            api: APIClient(configuration: server)
        )
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-edition", withExtension: "json"))
        let story = try XCTUnwrap(
            JSONDecoder().decode(EditionPayload.self, from: Data(contentsOf: url)).items.first
        )

        _ = await repository.update(story: story, kind: .saved, value: true)

        let reopened = FeedbackRepository(
            context: ModelContext(container),
            api: APIClient(configuration: server)
        )
        XCTAssertTrue(reopened.state(for: story).isSaved)
    }

    func testQueuedDeepDiveSurvivesBundledStoryReload() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedStoryState.self,
            PendingMutation.self,
            configurations: configuration
        )
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let server = ServerConfiguration(defaults: defaults)
        let repository = FeedbackRepository(
            context: container.mainContext,
            api: APIClient(configuration: server)
        )
        let url = try XCTUnwrap(Bundle.main.url(forResource: "first-edition", withExtension: "json"))
        let story = try XCTUnwrap(
            JSONDecoder().decode(EditionPayload.self, from: Data(contentsOf: url)).items.first
        )

        _ = await repository.requestDeepDive(story: story)

        let reopened = FeedbackRepository(
            context: ModelContext(container),
            api: APIClient(configuration: server)
        )
        XCTAssertEqual(reopened.state(for: story).deepDiveStatus, .queued)
    }

    func testTerminalDeepDiveDoesNotRegressForSameRequest() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedStoryState.self,
            PendingMutation.self,
            configurations: configuration
        )
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let repository = FeedbackRepository(
            context: container.mainContext,
            api: APIClient(configuration: ServerConfiguration(defaults: defaults))
        )
        let requestedAt = "2026-07-12T06:30:00Z"
        _ = repository.state(
            for: story(
                deepDive: DeepDiveState(
                    status: .ready,
                    requestedAt: requestedAt,
                    title: "A finished investigation",
                    body: "The durable result.",
                    citations: []
                )
            )
        )

        let state = repository.state(
            for: story(
                deepDive: DeepDiveState(
                    status: .queued,
                    requestedAt: requestedAt,
                    title: nil,
                    body: nil,
                    citations: []
                )
            )
        )

        XCTAssertEqual(state.deepDiveStatus, .ready)
        XCTAssertEqual(state.deepDiveTitle, "A finished investigation")
        XCTAssertEqual(state.deepDiveBody, "The durable result.")
    }

    func testDeepDiveAdvancesAcrossEquivalentTimestampFormats() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedStoryState.self,
            PendingMutation.self,
            configurations: configuration
        )
        let defaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let repository = FeedbackRepository(
            context: container.mainContext,
            api: APIClient(configuration: ServerConfiguration(defaults: defaults))
        )
        _ = repository.state(
            for: story(
                deepDive: DeepDiveState(
                    status: .queued,
                    requestedAt: "2026-07-12T08:30:00+02:00",
                    title: nil,
                    body: nil,
                    citations: []
                )
            )
        )

        let state = repository.state(
            for: story(
                deepDive: DeepDiveState(
                    status: .ready,
                    requestedAt: "2026-07-12T06:30:00Z",
                    title: "Equivalent instant",
                    body: "Ready",
                    citations: []
                )
            )
        )

        XCTAssertEqual(state.deepDiveStatus, .ready)
        XCTAssertEqual(state.deepDiveTitle, "Equivalent instant")
    }

    private func story(deepDive: DeepDiveState) -> StoryItem {
        StoryItem(
            id: "deep-dive-story",
            position: 1,
            kind: "paper",
            topicIDs: ["testing"],
            title: "A story",
            summary: "Summary",
            body: "Body",
            whySelected: "Reason",
            sourceName: "Source",
            sourceURL: URL(string: "https://example.com/story")!,
            publishedAt: "2026-07-12T06:00:00Z",
            readingMinutes: 2,
            imageURL: nil,
            citations: [],
            feedback: .empty,
            deepDive: deepDive
        )
    }
}
