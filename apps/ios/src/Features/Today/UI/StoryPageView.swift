import SwiftUI

struct StoryPageView: View {
    let story: StoryItem
    let number: Int
    let total: Int
    let api: APIClient
    let relatedEvents: [EventItem]

    var body: some View {
        ScrollView {
            StoryArticleContent(story: story, api: api, relatedEvents: relatedEvents)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 64)
                .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
        .background(VerseTheme.storyBackground(for: story.id))
        .accessibilityValue("Story \(number) of \(total)")
        .accessibilityIdentifier("reader-story-page")
    }
}

#if DEBUG
#Preview("Story page") {
    StoryPageView(
        story: PreviewFixtures.story,
        number: 1,
        total: 10,
        api: APIClient(configuration: ServerConfiguration()),
        relatedEvents: []
    )
}
#endif
