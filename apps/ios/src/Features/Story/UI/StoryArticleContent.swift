import SwiftUI

struct StoryArticleContent: View {
    let story: StoryItem
    let api: APIClient
    let relatedEvents: [EventItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = story.imageURL {
                StoryImageView(url: imageURL, alt: story.imageAlt, api: api, height: nil)
                    .padding(.bottom, 28)
            }
            Text(story.title)
                .font(.title)
                .foregroundStyle(VerseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("story-title")
            StoryRelatedEventsView(events: relatedEvents)
            Text(story.body)
                .font(.body)
                .foregroundStyle(VerseTheme.ink)
                .lineSpacing(6)
                .textSelection(.enabled)
                .padding(.top, 28)
                .accessibilityIdentifier("story-body")
        }
    }
}
