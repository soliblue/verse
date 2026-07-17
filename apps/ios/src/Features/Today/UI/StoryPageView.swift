import SwiftUI

struct StoryPageView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let story: StoryItem
    let number: Int
    let total: Int

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 740 || dynamicTypeSize.isAccessibilitySize
            page(compact: compact)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Story \(number) of \(total). \(story.title). \(story.summary)"
        )
        .accessibilityHint("Opens the full story")
    }

    private func page(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 18 : 24) {
            Spacer(minLength: compact ? 54 : 80)

            Text(story.title)
                .font(.display(compact ? 34 : 40))
                .foregroundStyle(VerseTheme.ink)
                .minimumScaleFactor(0.86)
                .lineLimit(compact ? 4 : 5)

            Text(story.summary)
                .font(.reading(compact ? 17 : 20))
                .foregroundStyle(VerseTheme.secondaryInk)
                .lineSpacing(compact ? 3 : 5)
                .lineLimit(compact ? 7 : 9)

            Spacer(minLength: compact ? 48 : 88)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 52)
        .padding(.bottom, 24)
        .background(VerseTheme.storyBackground(for: story.id))
        .accessibilityIdentifier("reader-story-page")
    }
}

#if DEBUG
#Preview("Story page") {
    StoryPageView(story: PreviewFixtures.story, number: 1, total: 10)
}
#endif
