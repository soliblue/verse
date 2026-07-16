import SwiftUI

struct ExploreCalendarView: View {
    let payload: ExplorePayload
    let calendarRepository: CalendarRepository
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Previous week", systemImage: "chevron.left") {
                    moveWeek(-1)
                }
                .labelStyle(.iconOnly)
                .disabled(!canMoveWeek(-1))
                Spacer()
                Text(weekTitle)
                    .font(.utility(13))
                Spacer()
                Button("Next week", systemImage: "chevron.right") {
                    moveWeek(1)
                }
                .labelStyle(.iconOnly)
                .disabled(!canMoveWeek(1))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(isSelected(date) ? VerseTheme.ink : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isWithinHorizon(date))
                    .opacity(isWithinHorizon(date) ? 1 : 0.3)
                }
            }
            .padding(.horizontal, 12)

            List {
                if selectedOccurrences.isEmpty {
                    Text("No verified events on this day.")
                        .font(.reading(16))
                        .foregroundStyle(VerseTheme.secondaryInk)
                        .listRowBackground(VerseTheme.paper)
                }
                ForEach(selectedOccurrences) { occurrence in
                    if let event = event(for: occurrence) {
                        EventRowView(event: event, calendar: calendarRepository)
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

    private var weekDates: [Date] {
        let calendar = EventDateFormatting.calendar
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekTitle: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = EventDateFormatting.berlin
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
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

    private func moveWeek(_ value: Int) {
        let date = EventDateFormatting.calendar.date(
            byAdding: .weekOfYear,
            value: value,
            to: selectedDate
        ) ?? selectedDate
        selectedDate = clamped(date)
    }

    private func canMoveWeek(_ value: Int) -> Bool {
        guard let first = weekDates.first, let last = weekDates.last else { return false }
        if value < 0 {
            guard let start = horizonStart else { return true }
            return start < first
        }
        guard let end = horizonEnd else { return true }
        return end > last
    }

    private func isWithinHorizon(_ date: Date) -> Bool {
        let day = EventDateFormatting.calendar.startOfDay(for: date)
        if let start = horizonStart, day < start { return false }
        if let end = horizonEnd, day > end { return false }
        return true
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
