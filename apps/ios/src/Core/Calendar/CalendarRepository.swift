import EventKit
import Foundation

@MainActor
final class CalendarRepository {
    enum Preparation {
        case ready(CalendarEditorRequest)
        case denied
        case unresolved
    }

    private static let sharedEventStore = EKEventStore()
    private let links: CalendarLinkStore

    var eventStore: EKEventStore { Self.sharedEventStore }

    init(defaults: UserDefaults = .standard) {
        links = CalendarLinkStore(defaults: defaults)
    }

    nonisolated deinit {}

    func state(for item: EventItem) -> CalendarLinkState {
        links.state(
            occurrenceID: item.occurrence.id,
            fingerprint: fingerprint(for: item),
            isCancelled: item.occurrence.state == .cancelled,
            isEnded: item.occurrence.state == .ended
        )
    }

    func prepare(_ item: EventItem) async -> Preparation {
        guard await requestAccess() else { return .denied }
        let link = links.link(for: item.occurrence.id)
        let event: EKEvent
        if let link {
            guard
                let identifier = link.eventIdentifier,
                let linkedEvent = eventStore.event(withIdentifier: identifier)
            else { return .unresolved }
            event = linkedEvent
        } else {
            event = EKEvent(eventStore: eventStore)
        }
        if event.calendar == nil {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }
        event.title = item.title
        event.startDate = item.occurrence.startDate ?? Date()
        event.endDate = item.occurrence.endDate
            ?? Calendar(identifier: .gregorian).date(
                byAdding: .hour,
                value: 2,
                to: event.startDate
            )!
        event.location = item.venue.address ?? item.venue.name
        event.url = item.officialURL
        event.notes = [
            item.occurrence.bookingLabel,
            item.whySelected,
            item.bookingURL?.absoluteString,
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
        return .ready(
            CalendarEditorRequest(
                event: event,
                occurrenceID: item.occurrence.id,
                fingerprint: fingerprint(for: item)
            )
        )
    }

    func record(_ request: CalendarEditorRequest) {
        let identifier = resolveIdentifier(for: request)
        recordLink(
            occurrenceID: request.occurrenceID,
            eventIdentifier: identifier,
            fingerprint: request.fingerprint
        )
    }

    func recordLink(occurrenceID: String, eventIdentifier: String?, fingerprint: String) {
        links.record(
            occurrenceID: occurrenceID,
            eventIdentifier: eventIdentifier,
            fingerprint: fingerprint
        )
    }

    private func resolveIdentifier(for request: CalendarEditorRequest) -> String? {
        if let identifier = request.event.eventIdentifier { return identifier }
        eventStore.refreshSourcesIfNecessary()
        let start = request.event.startDate.addingTimeInterval(-60)
        let end = request.event.startDate.addingTimeInterval(60)
        let predicate = eventStore.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )
        return eventStore.events(matching: predicate).first {
            $0.title == request.event.title
                && abs($0.startDate.timeIntervalSince(request.event.startDate)) < 1
                && normalizedLocation($0.location) == normalizedLocation(request.event.location)
        }?.eventIdentifier
    }

    private func normalizedLocation(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func requestAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .notDetermined:
            return (try? await eventStore.requestFullAccessToEvents()) == true
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    private func fingerprint(for item: EventItem) -> String {
        [
            item.title,
            item.occurrence.startAt,
            item.occurrence.endAt ?? "",
            item.venue.address ?? item.venue.name,
            item.occurrence.state.rawValue,
        ].joined(separator: "|")
    }
}
