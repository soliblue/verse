import SwiftUI

struct EventRowView: View {
    let event: EventItem
    let calendar: CalendarRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: event) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(EventDateFormatting.day(event.occurrence.startAt))
                        Text("·")
                        Text(EventDateFormatting.time(event.occurrence.startAt))
                        Spacer()
                        EventStatusBadge(occurrence: event.occurrence)
                    }
                    .font(.utility(12))
                    .foregroundStyle(VerseTheme.secondaryInk)

                    Text(event.title)
                        .font(.display(23))
                        .foregroundStyle(VerseTheme.ink)

                    Text(
                        [event.venue.name, event.venue.distanceLabel]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                    )
                        .font(.utility(12))
                        .foregroundStyle(VerseTheme.secondaryInk)

                    Text(event.whySelected)
                        .font(.reading(15))
                        .foregroundStyle(VerseTheme.secondaryInk)
                        .lineLimit(2)
                }
            }
            .buttonStyle(.plain)

            if event.occurrence.state != .ended {
                EventCalendarButton(event: event, calendar: calendar)
                    .font(.utility(13))
                    .foregroundStyle(VerseTheme.ink)
            }
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("event-row-\(event.id)")
    }
}
