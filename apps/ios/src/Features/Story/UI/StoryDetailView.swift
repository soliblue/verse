import SwiftUI

struct StoryDetailView: View {
    let story: StoryItem
    let feedback: FeedbackRepository
    let explore: ExploreRepository
    @State private var store = StoryDetailStore()
    @State private var showsDetails = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(story.title)
                    .font(.display(38))
                    .foregroundStyle(VerseTheme.ink)
                    .accessibilityIdentifier("story-detail")
                StoryRelatedEventsView(
                    events: explore.events(ids: story.relatedEventIDs ?? [])
                )
                Text(story.body)
                    .font(.reading(18))
                    .foregroundStyle(VerseTheme.ink)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 64)
        }
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
