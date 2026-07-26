import SwiftUI

struct StoryDetailView: View {
    let story: StoryItem
    let api: APIClient
    let feedback: FeedbackRepository
    let explore: ExploreRepository
    @State private var store = StoryDetailStore()

    var body: some View {
        ScrollView {
            StoryArticleContent(
                story: story,
                api: api,
                relatedEvents: explore.events(ids: story.relatedEventIDs ?? [])
            )
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 64)
        }
        .accessibilityIdentifier("story-detail")
        .background(VerseTheme.paper)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                StoryPageToolbar(
                    preference: store.preference,
                    isDisabled: store.isSending,
                    foregroundColor: VerseTheme.ink,
                    onPreference: { preference in
                        Task {
                            await store.setPreference(preference, story: story, repository: feedback)
                        }
                    }
                )
            }
        }
        .task { await store.load(story: story, repository: feedback) }
    }
}
