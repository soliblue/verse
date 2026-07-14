import SwiftUI

struct StoryRowView: View {
    let story: StoryItem
    var isSaved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(story.kind.replacingOccurrences(of: "_", with: " ").uppercased())
                    .font(.utility(12))
                    .tracking(0.8)
                    .foregroundStyle(VerseTheme.secondaryInk)
                Spacer()
                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(VerseTheme.blue)
                        .accessibilityLabel("Saved")
                }
            }
            Text(story.title)
                .font(.display(22))
                .foregroundStyle(VerseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(story.summary)
                .font(.reading(15))
                .lineSpacing(2)
                .foregroundStyle(VerseTheme.secondaryInk)
                .lineLimit(3)
            HStack(spacing: 6) {
                Text(story.sourceName)
                Text("·")
                Text("\(story.readingMinutes) min")
            }
            .font(.utility(12))
            .foregroundStyle(VerseTheme.secondaryInk)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview("Story") {
    StoryRowView(story: PreviewFixtures.story, isSaved: true)
        .padding()
        .background(VerseTheme.paper)
}
#endif
