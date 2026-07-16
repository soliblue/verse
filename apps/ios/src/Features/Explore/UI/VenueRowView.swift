import SwiftUI

struct VenueRowView: View {
    let venue: Venue
    let nextEvent: EventItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(venue.name)
                    .font(.display(22))
                Spacer()
                if let distance = venue.distanceLabel {
                    Text(distance.uppercased())
                        .font(.utility(10))
                        .foregroundStyle(VerseTheme.secondaryInk)
                }
            }
            Text(venue.whyWatched)
                .font(.reading(15))
                .foregroundStyle(VerseTheme.secondaryInk)
                .lineLimit(2)
            if let nextEvent {
                Text("Next · \(nextEvent.title)")
                    .font(.utility(12))
                    .foregroundStyle(VerseTheme.ink)
            }
        }
        .padding(.vertical, 9)
    }
}
