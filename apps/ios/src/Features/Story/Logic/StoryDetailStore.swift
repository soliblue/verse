import Observation

@MainActor
@Observable
final class StoryDetailStore {
    private(set) var state: CachedStoryState?
    private(set) var isSending = false

    var isSaved: Bool { state?.isSaved ?? false }
    var preference: FeedbackPreference? { state?.preference }
    var deepDiveStatus: DeepDiveStatus { state?.deepDiveStatus ?? .notRequested }

    func load(story: StoryItem, repository: FeedbackRepository) async {
        state = repository.state(for: story)
        if state?.isSeen == false {
            state = await repository.update(story: story, kind: .seen, value: true)
        }
    }

    func toggleSaved(story: StoryItem, repository: FeedbackRepository) async {
        isSending = true
        state = await repository.update(story: story, kind: .saved, value: !isSaved)
        isSending = false
    }

    func setPreference(
        _ preference: FeedbackPreference,
        story: StoryItem,
        repository: FeedbackRepository
    ) async {
        isSending = true
        state = await repository.update(
            story: story,
            kind: FeedbackKind(rawValue: preference.rawValue) ?? .moreLikeThis,
            value: self.preference != preference
        )
        isSending = false
    }

    func requestDeepDive(story: StoryItem, repository: FeedbackRepository) async {
        isSending = true
        state = await repository.requestDeepDive(story: story)
        isSending = false
    }
}
