import SwiftUI

struct ExplorePlacesView: View {
    let payload: ExplorePayload

    var body: some View {
        List {
            ForEach(payload.venues.filter { $0.watchState != .archived }) { venue in
                NavigationLink(value: venue) {
                    VenueRowView(venue: venue, nextEvent: nextEvent(for: venue))
                }
                .listRowBackground(VerseTheme.paper)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func nextEvent(for venue: Venue) -> EventItem? {
        payload.allEvents.first { $0.occurrence.id == venue.nextEventID }
    }
}
