import SwiftUI

struct StoryDetailView: View {
    let story: StoryItem
    let api: APIClient
    let feedback: FeedbackRepository
    let explore: ExploreRepository
    @State private var store = StoryDetailStore()
    @State private var showsDetails = false

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
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await store.toggleSaved(story: story, repository: feedback) }
                } label: {
                    Image(systemName: store.isSaved ? "bookmark.fill" : "bookmark")
                }
                .disabled(store.isSending)
                .accessibilityLabel(store.isSaved ? "Remove bookmark" : "Save story")
                .accessibilityIdentifier("story-save")

                StoryActionsMenu(
                    sourceURL: story.sourceURL,
                    preference: store.preference,
                    deepDiveStatus: store.deepDiveStatus,
                    isDisabled: store.isSending,
                    onPreference: { preference in
                        Task {
                            await store.setPreference(preference, story: story, repository: feedback)
                        }
                    },
                    onDeepDive: {
                        Task { await store.requestDeepDive(story: story, repository: feedback) }
                    },
                    onShowDetails: { showsDetails = true }
                )
            }
        }
        .sheet(isPresented: $showsDetails) {
            StoryInfoSheet(story: story, state: store.state)
        }
        .task { await store.load(story: story, repository: feedback) }
    }
}
