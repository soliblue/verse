import SwiftUI

struct StoryPageView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("verse.textOnly") private var textOnly = false
    let story: StoryItem
    let number: Int
    let total: Int
    let covers: CoverRepository?

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 740 || dynamicTypeSize.isAccessibilitySize

            if !textOnly, let imageURL = story.imageURL {
                mediaPage(imageURL: imageURL, size: geometry.size, compact: compact)
            } else {
                textPage(compact: compact)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Story \(number) of \(total). \(story.title). \(story.summary)"
        )
        .accessibilityHint("Opens the full story")
    }

    private func mediaPage(imageURL: URL, size: CGSize, compact: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            StoryCoverImage(
                url: imageURL,
                title: story.title,
                covers: covers,
                contentMode: .fill
            )
            .frame(width: size.width, height: size.height)
            .scaleEffect(1.06)
            .blur(radius: 10, opaque: true)

            LinearGradient(
                colors: [
                    VerseTheme.mediaScrim.opacity(0.38),
                    VerseTheme.mediaScrim.opacity(0.06),
                    VerseTheme.mediaScrim.opacity(0.2),
                    VerseTheme.mediaScrim.opacity(0.88),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: compact ? 12 : 16) {
                Text(story.title)
                    .font(.display(compact ? 34 : 40))
                    .foregroundStyle(VerseTheme.mediaInk)
                    .minimumScaleFactor(0.84)
                    .lineLimit(compact ? 4 : 5)

                Text(story.summary)
                    .font(.reading(compact ? 17 : 20))
                    .foregroundStyle(VerseTheme.mediaSecondaryInk)
                    .lineSpacing(compact ? 3 : 5)
                    .lineLimit(compact ? 4 : 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, compact ? 34 : 48)
        }
        .frame(width: size.width, height: size.height)
        .background(VerseTheme.mediaScrim)
        .clipped()
        .accessibilityIdentifier("reader-cover-page")
    }

    private func textPage(compact: Bool) -> some View {
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
        .background(VerseTheme.paper)
    }
}

#if DEBUG
#Preview("Story page") {
    StoryPageView(story: PreviewFixtures.story, number: 1, total: 10, covers: nil)
}
#endif
