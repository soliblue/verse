import SwiftUI

struct TodayStoryPage: View {
    let story: StoryItem
    let number: Int
    let total: Int
    let covers: CoverRepository

    var body: some View {
        NavigationLink(value: story) {
            StoryPageView(story: story, number: number, total: total, covers: covers)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reader-story-\(number)")
    }
}
