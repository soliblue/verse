import SwiftUI

struct VerseMark: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.horizon.fill")
                .foregroundStyle(VerseTheme.amber)
            Text("VERSE")
                .font(.system(.headline, design: .serif, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(VerseTheme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("verse-mark")
    }
}
