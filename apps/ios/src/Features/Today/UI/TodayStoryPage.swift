import SwiftUI

struct TodayStoryPage: View {
    let story: StoryItem
    let number: Int
    let total: Int
    let feedback: FeedbackRepository
    @State private var store = StoryDetailStore()

    var body: some View {
        ZStack(alignment: .top) {
            NavigationLink(value: story) {
                StoryPageView(story: story, number: number, total: total)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reader-story-\(number)")

            StoryPageToolbar(
                number: number,
                sourceURL: story.sourceURL,
                isSaved: store.isSaved,
                preference: store.preference,
                deepDiveStatus: store.deepDiveStatus,
                isDisabled: store.isSending,
                onSave: {
                    Task { await store.toggleSaved(story: story, repository: feedback) }
                },
                onPreference: { preference in
                    Task {
                        await store.setPreference(preference, story: story, repository: feedback)
                    }
                },
                onDeepDive: {
                    Task { await store.requestDeepDive(story: story, repository: feedback) }
                }
            )
        }
        .task { await store.load(story: story, repository: feedback, markSeen: false) }
    }
}
