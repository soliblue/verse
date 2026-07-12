import Observation

@MainActor
@Observable
final class LibraryStore {
    private(set) var savedStories: [StoryItem] = []
    private(set) var editions: [EditionSummary] = []
    private(set) var currentEditionID: String?
    private(set) var isLoading = false
    private(set) var refreshFailed = false

    func load(editions: EditionRepository, feedback: FeedbackRepository) async {
        isLoading = self.editions.isEmpty && savedStories.isEmpty
        reloadLocal(editions: editions, feedback: feedback)
        self.editions = await editions.summaries()
        isLoading = false
    }

    func refresh(editions: EditionRepository, feedback: FeedbackRepository) async {
        let local = editions.localSummaries()
        let refreshed = await editions.summaries()
        self.editions = refreshed
        refreshFailed = refreshed == local && !local.isEmpty
        reloadLocal(editions: editions, feedback: feedback)
    }

    func reloadLocal(editions: EditionRepository, feedback: FeedbackRepository) {
        savedStories = editions.stories(ids: feedback.savedStoryIDs())
        currentEditionID = editions.localToday()?.id
        if self.editions.isEmpty {
            self.editions = editions.localSummaries()
        }
    }

    var previousEditions: [EditionSummary] {
        editions.filter { $0.id != currentEditionID }
    }
}
