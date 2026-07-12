import SwiftUI

struct CitationRow: View {
    let citation: Citation

    var body: some View {
        Link(destination: citation.url) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(MorrowTheme.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(citation.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MorrowTheme.ink)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 5) {
                        Text(citation.sourceName)
                        if let publishedAt = citation.publishedAt {
                            Text("·")
                            Text(DateFormatting.shortDate(publishedAt))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(MorrowTheme.secondaryInk)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
