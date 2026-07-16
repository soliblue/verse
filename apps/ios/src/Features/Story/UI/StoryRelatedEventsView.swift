import SwiftUI

struct StoryRelatedEventsView: View {
    let events: [EventItem]
    let feedback: EventFeedbackRepository
    let calendar: CalendarRepository

    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(events, id: \.occurrence.id) { event in
                    VStack(alignment: .leading, spacing: 8) {
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
                        if isEnded(event) {
                            Button("Mark attended", systemImage: "checkmark") {
                                Task {
                                    _ = await feedback.update(
                                        eventID: event.id,
                                        occurrenceID: event.occurrence.id,
                                        kind: .attended
                                    )
                                }
                            }
                            .font(.utility(13))
                        } else {
                            EventCalendarButton(event: event, calendar: calendar)
                                .font(.utility(13))
                        }
                    }
                    .padding(14)
                    .background(VerseTheme.surface)
                }
            }
            .padding(.top, 24)
            .accessibilityIdentifier("story-related-events")
        }
    }

    private func isEnded(_ event: EventItem) -> Bool {
        event.occurrence.state == .ended
            || (event.occurrence.endDate ?? event.occurrence.startDate ?? .distantFuture) < Date()
    }
}
