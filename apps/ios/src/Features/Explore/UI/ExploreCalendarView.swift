import SwiftUI

struct ExploreCalendarView: View {
    let payload: ExplorePayload
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(horizonDates, id: \.self) { date in
                        Button {
                            selectedDate = date
                        } label: {
                            VStack(spacing: 6) {
                                Text(weekday(date))
                                    .font(.utility(10))
                                Text(dayNumber(date))
                                    .font(.utility(15))
                                Circle()
                                    .frame(width: 4, height: 4)
                                    .opacity(hasEvents(date) ? 1 : 0)
                            }
                            .foregroundStyle(isSelected(date) ? VerseTheme.paper : VerseTheme.ink)
                            .frame(width: 54)
                            .padding(.vertical, 9)
                            .background(isSelected(date) ? VerseTheme.ink : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("calendar-day-\(EventDateFormatting.dayKey(date))")
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(height: 78)

            List {
                if selectedOccurrences.isEmpty {
                    Text("No verified events on this day.")
                        .font(.reading(16))
                        .foregroundStyle(VerseTheme.secondaryInk)
                        .listRowBackground(VerseTheme.paper)
                }
                ForEach(selectedOccurrences) { occurrence in
                    if let event = event(for: occurrence) {
                        EventRowView(event: event)
                            .listRowBackground(VerseTheme.paper)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(occurrence.title)
                                .font(.display(20))
                            Text(
                                "\(EventDateFormatting.time(occurrence.startAt)) · "
                                    + (venue(for: occurrence)?.name ?? "Berlin")
                            )
                            .font(.utility(12))
                            .foregroundStyle(VerseTheme.secondaryInk)
                            EventStatusBadge(occurrence: occurrence)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(VerseTheme.paper)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .task(id: payload.id) {
            selectedDate = clamped(selectedDate)
        }
    }

    private var horizonDates: [Date] {
        let calendar = EventDateFormatting.calendar
        guard let start = horizonStart, let end = horizonEnd else { return [selectedDate] }
        let count = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return (0...max(count, 0)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    private var selectedOccurrences: [EventOccurrence] {
        payload.calendar
            .filter {
                EventDateFormatting.dayKey($0.startAt)
                    == EventDateFormatting.dayKey(selectedDate)
                    && $0.state != .ended
                    && $0.state != .cancelled
            }
            .sorted { $0.startAt < $1.startAt }
    }

    private func event(for occurrence: EventOccurrence) -> EventItem? {
        payload.allEvents.first {
            $0.id == occurrence.eventID && $0.occurrence.id == occurrence.id
        }
    }

    private func venue(for occurrence: EventOccurrence) -> Venue? {
        payload.venues.first { $0.id == occurrence.venueID }
    }

    private func hasEvents(_ date: Date) -> Bool {
        payload.calendar.contains {
            EventDateFormatting.dayKey($0.startAt) == EventDateFormatting.dayKey(date)
                && $0.state != .ended && $0.state != .cancelled
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        EventDateFormatting.dayKey(date) == EventDateFormatting.dayKey(selectedDate)
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = EventDateFormatting.berlin
        formatter.dateFormat = "EE"
        return formatter.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        EventDateFormatting.calendar.component(.day, from: date).formatted()
    }

    private func clamped(_ date: Date) -> Date {
        let day = EventDateFormatting.calendar.startOfDay(for: date)
        if let start = horizonStart, day < start { return start }
        if let end = horizonEnd, day > end { return end }
        return day
    }

    private var horizonStart: Date? {
        EventDateFormatting.horizonDate(payload.horizonStart)
    }

    private var horizonEnd: Date? {
        EventDateFormatting.horizonDate(payload.horizonEnd)
    }
}
