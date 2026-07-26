import SwiftUI

struct EditionSummaryRow: View {
    let edition: EditionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateFormatting.editionDate(edition.date).uppercased())
                .font(.caption)
                .tracking(0.7)
                .foregroundStyle(VerseTheme.secondaryInk)
            Text(edition.title)
                .font(.headline)
                .foregroundStyle(VerseTheme.ink)
            Text(edition.dek)
                .font(.subheadline)
                .foregroundStyle(VerseTheme.secondaryInk)
                .lineLimit(2)
            Text("\(edition.itemCount) stories")
                .font(.caption)
                .foregroundStyle(VerseTheme.secondaryInk)
        }
        .padding(.vertical, 8)
    }
}
