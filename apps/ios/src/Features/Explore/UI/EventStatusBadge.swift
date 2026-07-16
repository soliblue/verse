import SwiftUI

struct EventStatusBadge: View {
    let occurrence: EventOccurrence

    var body: some View {
        Text(occurrence.bookingLabel.uppercased())
            .font(.utility(10))
            .tracking(0.7)
            .foregroundStyle(occurrence.soldOut ? VerseTheme.secondaryInk : VerseTheme.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(VerseTheme.elevated)
            .clipShape(Capsule())
    }
}
