import SwiftUI

struct EditionSummaryRow: View {
    let edition: EditionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DateFormatting.editionDate(edition.date).uppercased())
                .font(.utility(12))
                .tracking(0.7)
                .foregroundStyle(VerseTheme.secondaryInk)
            Text(edition.title)
                .font(.display(20))
                .foregroundStyle(VerseTheme.ink)
            Text(edition.dek)
                .font(.reading(14))
                .foregroundStyle(VerseTheme.secondaryInk)
                .lineLimit(2)
            Text("\(edition.itemCount) stories")
                .font(.utility(12))
                .foregroundStyle(VerseTheme.secondaryInk)
        }
        .padding(.vertical, 8)
    }
}
