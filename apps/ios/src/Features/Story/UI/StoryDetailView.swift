import SwiftUI

struct StoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("verse.textOnly") private var textOnly = false
    let story: StoryItem
    let feedback: FeedbackRepository
    let explore: ExploreRepository
    let eventFeedback: EventFeedbackRepository
    let calendar: CalendarRepository
    let covers: CoverRepository
    @State private var store = StoryDetailStore()
    @State private var showsDetails = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !textOnly, let imageURL = story.imageURL {
                    StoryCoverImage(url: imageURL, title: story.title, covers: covers)
                        .frame(height: 260)
                        .padding(.bottom, 32)
                }
                Text(story.title)
                    .font(.display(38))
                    .foregroundStyle(VerseTheme.ink)
                    .accessibilityIdentifier("story-detail")
                StoryRelatedEventsView(
                    events: explore.events(ids: story.relatedEventIDs ?? []),
                    feedback: eventFeedback,
                    calendar: calendar
                )
                Text(story.body)
                    .font(.reading(18))
                    .foregroundStyle(VerseTheme.ink)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.top, 84)
            .padding(.bottom, 64)
        }
        .background(VerseTheme.paper)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            StoryToolbar(
                sourceURL: story.sourceURL,
                isSaved: store.isSaved,
                preference: store.preference,
                deepDiveStatus: store.deepDiveStatus,
                isDisabled: store.isSending,
                onBack: { dismiss() },
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
                },
                onShowDetails: { showsDetails = true }
            )
        }
        .sheet(isPresented: $showsDetails) {
            StoryInfoSheet(story: story, state: store.state)
        }
        .task { await store.load(story: story, repository: feedback) }
    }
}
