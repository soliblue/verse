import SwiftUI

struct EventDetailView: View {
    let event: EventItem
    let explore: ExploreRepository
    let feedback: EventFeedbackRepository
    let calendar: CalendarRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(event.title)
                        .font(.display(38))
                        .foregroundStyle(VerseTheme.ink)
                        .accessibilityIdentifier("event-detail")
                    Text(event.description)
                        .font(.reading(18))
                        .foregroundStyle(VerseTheme.secondaryInk)
                        .lineSpacing(5)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        EventDateFormatting.full(event.occurrence.startAt),
                        systemImage: "calendar"
                    )
                    if let doors = event.occurrence.doorsAt {
                        Label("Doors \(EventDateFormatting.time(doors))", systemImage: "door.left.hand.open")
                    }
                    Label(event.venue.name, systemImage: "mappin")
                    if let address = event.venue.address { Text(address) }
                    Label(event.occurrence.bookingLabel, systemImage: "eurosign")
                }
                .font(.reading(16))

                VStack(alignment: .leading, spacing: 12) {
                    EventCalendarButton(event: event, calendar: calendar)
                    if let routeURL {
                        Link(destination: routeURL) {
                            Label("Route", systemImage: "arrow.triangle.turn.up.right.diamond")
                        }
                    }
                    if let bookingURL = event.bookingURL ?? event.occurrence.bookingURL {
                        Link(destination: bookingURL) {
                            Label(event.occurrence.rsvpRequired ? "Reserve" : "Book", systemImage: "ticket")
                        }
                    }
                }
                .font(.reading(16))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Why this fits")
                        .font(.utility(12))
                        .tracking(0.9)
                        .textCase(.uppercase)
                    Text(event.whySelected)
                        .font(.reading(18))
                        .lineSpacing(5)
                }

                EventFeedbackBar(event: event, repository: feedback)

                VStack(alignment: .leading, spacing: 10) {
                    Link(destination: event.officialURL) {
                        Label("Open official event", systemImage: "arrow.up.right")
                    }
                    Text("\(event.sourceName) · checked \(DateFormatting.shortDate(event.checkedAt))")
                        .font(.utility(12))
                        .foregroundStyle(VerseTheme.secondaryInk)
                }

                if !relatedEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Next at \(event.venue.name)")
                            .font(.display(22))
                        ForEach(relatedEvents, id: \.occurrence.id) { related in
                            NavigationLink(value: related) {
                                Text(related.title)
                                    .font(.reading(17))
                            }
                        }
                    }
                }

                Menu {
                    Button("Not for me", systemImage: "xmark") { update(.notForMe) }
                    Button("Too far", systemImage: "location.slash") { update(.tooFar) }
                    Button("Too expensive", systemImage: "eurosign") { update(.tooExpensive) }
                    Button("Sold out before I could book", systemImage: "ticket") { update(.soldOut) }
                    Button("More from this venue", systemImage: "building.2") { update(.moreFromVenue) }
                    Button("More like this", systemImage: "plus") { update(.moreLikeThis) }
                } label: {
                    Label("More feedback", systemImage: "ellipsis")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(VerseTheme.paper)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var relatedEvents: [EventItem] {
        Array(
            (explore.local()?.allEvents ?? [])
                .filter {
                    $0.occurrence.id != event.occurrence.id
                        && $0.venue.id == event.venue.id
                }
                .sorted {
                    ($0.occurrence.startDate ?? .distantFuture)
                        < ($1.occurrence.startDate ?? .distantFuture)
                }
                .prefix(2)
        )
    }

    private var routeURL: URL? {
        let destination = event.venue.address ?? event.venue.name
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "daddr", value: destination)]
        return components?.url
    }

    private func update(_ kind: EventFeedbackKind) {
        Task {
            _ = await feedback.update(
                eventID: event.id,
                occurrenceID: event.occurrence.id,
                kind: kind
            )
        }
    }
}
