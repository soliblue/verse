import SwiftUI

struct VerseMark: View {
    var body: some View {
        HStack(spacing: VerseTokens.Spacing.s) {
            VerseGlyph()
            Text("VERSE")
                .font(.display(VerseTokens.Text.xl))
                .tracking(1.2)
                .foregroundStyle(VerseTheme.foreground)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verse")
        .accessibilityIdentifier("verse-mark")
    }
}
