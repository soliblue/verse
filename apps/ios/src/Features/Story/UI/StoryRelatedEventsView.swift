import SwiftUI

struct StoryRelatedEventsView: View {
    let events: [EventItem]

    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(events, id: \.occurrence.id) { event in
                    NavigationLink(value: event) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(EventDateFormatting.full(event.occurrence.startAt))
                                .font(.utility(11))
                                .foregroundStyle(VerseTheme.secondaryInk)
                            Text(event.title)
                                .font(.display(20))
                            Text("\(event.venue.name) · \(event.occurrence.bookingLabel)")
                                .font(.utility(12))
                                .foregroundStyle(VerseTheme.secondaryInk)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                    .background(VerseTheme.surface)
                }
            }
            .padding(.top, 24)
            .accessibilityIdentifier("story-related-events")
        }
    }
}
