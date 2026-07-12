import SwiftUI

struct MorrowMark: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.horizon.fill")
                .foregroundStyle(MorrowTheme.amber)
            Text("MORROW")
                .font(.system(.headline, design: .serif, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(MorrowTheme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("morrow-mark")
    }
}
