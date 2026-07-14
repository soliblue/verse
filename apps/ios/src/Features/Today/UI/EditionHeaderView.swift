import SwiftUI

struct EditionHeaderView: View {
    let edition: EditionPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VerseMark()
            Text(DateFormatting.editionDate(edition.date).uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(VerseTheme.amber)
            Text(edition.title)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(VerseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(edition.dek)
                .font(.body)
                .foregroundStyle(VerseTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Label("\(edition.items.count) stories", systemImage: "rectangle.stack")
                Spacer()
                Text("A finite edition")
            }
            .font(.caption)
            .foregroundStyle(VerseTheme.secondaryInk)
            Divider()
                .overlay(VerseTheme.ink.opacity(0.25))
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

#if DEBUG
#Preview("Edition header") {
    EditionHeaderView(edition: PreviewFixtures.edition)
        .padding()
        .background(VerseTheme.paper)
}
#endif
