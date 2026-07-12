import Foundation
import Observation

@MainActor
@Observable
final class TodayStore {
    private(set) var edition: EditionPayload?
    private(set) var isLoading = false
    private(set) var isRefreshing = false
    private(set) var statusMessage: String?
    private(set) var hasLoaded = false

    func load(
        editions: EditionRepository,
        feedback: FeedbackRepository,
        topics: TopicsRepository,
        configuration: ServerConfiguration
    ) async {
        isLoading = edition == nil
        edition = editions.localToday()
        if let edition {
            feedback.ingest(edition)
        }
        isLoading = false
        await feedback.flushPending()
        _ = await topics.syncPending()
        if configuration.isConfigured {
            await refresh(
                editions: editions,
                feedback: feedback,
                topics: topics,
                configuration: configuration
            )
        }
        if edition == nil {
            statusMessage = "The bundled edition could not be opened."
        }
        hasLoaded = true
    }

    func refresh(
        editions: EditionRepository,
        feedback: FeedbackRepository,
        topics: TopicsRepository,
        configuration: ServerConfiguration
    ) async {
        guard !isRefreshing else { return }
        guard configuration.isConfigured else {
            statusMessage = "Add the VPS address in Settings to refresh."
            return
        }
        isRefreshing = true
        await feedback.flushPending()
        _ = await topics.syncPending()
        if let fresh = await editions.refreshToday() {
            edition = fresh
            feedback.ingest(fresh)
            statusMessage = nil
        } else {
            statusMessage =
                "Morrow could not refresh from the VPS. "
                + "Your downloaded edition is still available."
        }
        isRefreshing = false
    }
}
