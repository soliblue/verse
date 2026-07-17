import SwiftUI

struct VenueDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let venue: Venue
    let feedback: VenueFeedbackRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(venue.name)
                    .font(.display(38))
                Text(venue.whyWatched)
                    .font(.reading(18))
                    .foregroundStyle(VerseTheme.secondaryInk)
                    .lineSpacing(5)
                if let distance = venue.distanceLabel {
                    Label(distance, systemImage: "bicycle")
                        .font(.reading(16))
                }
                if let address = venue.address {
                    Label(address, systemImage: "mappin")
                        .font(.reading(16))
                }
                Link(destination: venue.calendarURL ?? venue.officialURL) {
                    Label("Official calendar", systemImage: "arrow.up.right")
                }

                Button("More from here", systemImage: "plus") {
                    update(.moreFromHere)
                }
                Button("Mute this place", systemImage: "speaker.slash", role: .destructive) {
                    update(.mute)
                }
            }
            .padding(24)
        }
        .background(VerseTheme.paper)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func update(_ kind: VenueFeedbackKind) {
        Task {
            await feedback.update(venueID: venue.id, kind: kind)
            dismiss()
        }
    }
}
