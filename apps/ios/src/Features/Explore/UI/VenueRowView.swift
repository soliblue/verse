import SwiftUI

struct VenueRowView: View {
    let venue: Venue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(venue.name)
                    .font(.headline)
                Spacer()
                if let distance = venue.distanceLabel {
                    Text(distance.uppercased())
                        .font(.caption2)
                        .foregroundStyle(VerseTheme.secondaryInk)
                }
            }
            Text(venue.whyWatched)
                .font(.subheadline)
                .foregroundStyle(VerseTheme.secondaryInk)
                .lineLimit(2)
        }
        .padding(.vertical, 9)
    }
}
