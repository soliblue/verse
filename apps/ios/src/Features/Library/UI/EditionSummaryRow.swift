import SwiftUI

struct EditionSummaryRow: View {
    let edition: EditionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateFormatting.editionDate(edition.date).uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.7)
                .foregroundStyle(VerseTheme.amber)
            Text(edition.title)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundStyle(VerseTheme.ink)
            Text(edition.dek)
                .font(.caption)
                .foregroundStyle(VerseTheme.secondaryInk)
                .lineLimit(2)
            Text("\(edition.itemCount) stories")
                .font(.caption2)
                .foregroundStyle(VerseTheme.secondaryInk)
        }
        .padding(.vertical, 8)
    }
}
