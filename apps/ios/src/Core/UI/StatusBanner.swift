import SwiftUI

struct StatusBanner: View {
    let message: String
    let systemImage: String

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(VerseTheme.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(VerseTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
    }
}
