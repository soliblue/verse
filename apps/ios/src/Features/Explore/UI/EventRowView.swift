import SwiftUI

struct EventRowView: View {
    let event: EventItem

    var body: some View {
        NavigationLink(value: event) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(EventDateFormatting.time(event.occurrence.startAt))
                    Spacer()
                    EventStatusBadge(occurrence: event.occurrence)
                }
                .font(.caption)
                .foregroundStyle(VerseTheme.secondaryInk)

                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(VerseTheme.ink)

                Text(
                    [event.venue.name, event.venue.distanceLabel]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                )
                    .font(.caption)
                    .foregroundStyle(VerseTheme.secondaryInk)

                Text(event.whySelected)
                    .font(.subheadline)
                    .foregroundStyle(VerseTheme.secondaryInk)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .accessibilityIdentifier("event-row-\(event.id)")
    }
}
