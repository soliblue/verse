import SwiftUI

struct TodayStoryPage: View {
    let story: StoryItem
    let number: Int
    let total: Int
    let api: APIClient

    var body: some View {
        NavigationLink(value: story) {
            StoryPageView(story: story, number: number, total: total, api: api)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reader-story-\(number)")
    }
}
