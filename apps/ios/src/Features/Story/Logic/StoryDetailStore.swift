import Observation

@MainActor
@Observable
final class StoryDetailStore {
    private(set) var state: CachedStoryState?
    private(set) var isSending = false

    var preference: FeedbackPreference? { state?.preference }

    func load(
        story: StoryItem,
        repository: FeedbackRepository,
        markSeen: Bool = true
    ) async {
        state = repository.state(for: story)
        if markSeen, state?.isSeen == false {
            state = await repository.update(story: story, kind: .seen, value: true)
        }
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

}
