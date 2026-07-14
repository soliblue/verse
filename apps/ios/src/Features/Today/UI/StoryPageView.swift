import SwiftUI

struct StoryPageView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let story: StoryItem
    let number: Int
    let total: Int

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 740 || dynamicTypeSize.isAccessibilitySize

            ZStack {
                VerseTheme.paper
                pixelField
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text("\(number) / \(total)")
                        Text("·")
                        Text(story.kind.replacingOccurrences(of: "_", with: " ").uppercased())
                    }
                    .font(.utility(12, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(VerseTheme.secondaryInk)

                    Text(story.title)
                        .font(.display(compact ? 34 : 40, weight: .bold))
                        .foregroundStyle(VerseTheme.ink)
                        .minimumScaleFactor(0.82)
                        .lineLimit(compact ? 4 : 5)
                        .padding(.top, compact ? 14 : 18)

                    Text(story.summary)
                        .font(.reading(compact ? 17 : 20))
                        .foregroundStyle(VerseTheme.secondaryInk)
                        .lineSpacing(compact ? 3 : 5)
                        .lineLimit(compact ? 6 : 7)
                        .padding(.top, compact ? 16 : 22)

                    Spacer(minLength: compact ? 12 : 18)

                    HStack(spacing: 7) {
                        Text(story.sourceName)
                            .lineLimit(1)
                        Text("·")
                        Text(DateFormatting.shortDate(story.publishedAt))
                        Text("·")
                        Text("\(story.readingMinutes) min")
                    }
                    .font(.utility(12, weight: .medium))
                    .foregroundStyle(VerseTheme.secondaryInk)

                    HStack {
                        Text("Read story")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VerseTheme.ink)
                    .padding(.top, compact ? 12 : 16)
                }
                .padding(.horizontal, 24)
                .padding(.top, compact ? 92 : 104)
                .padding(.bottom, compact ? 96 : 112)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Story \(number) of \(total). \(story.title). \(story.summary)"
        )
        .accessibilityHint("Opens the full story")
    }

    private var pixelField: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 22
            let columns = Int(size.width / cellSize) + 1
            let rows = Int(size.height / cellSize) + 1

            for row in 0..<rows {
                for column in 0..<columns {
                    let value = (row * 17 + column * 31 + story.position * 13) % 19
                    guard value < 3 else { continue }
                    let rect = CGRect(
                        x: CGFloat(column) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: value == 0 ? 3 : 2,
                        height: value == 0 ? 3 : 2
                    )
                    context.fill(
                        Path(rect),
                        with: .color(VerseTheme.accent.opacity(value == 0 ? 0.13 : 0.07))
                    )
                }
            }
        }
    }
}

#if DEBUG
#Preview("Story page") {
    StoryPageView(story: PreviewFixtures.story, number: 1, total: 10)
}
#endif
