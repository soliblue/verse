import Foundation

@MainActor
final class CalendarLinkStore {
    private static let storageKey = "verse.calendarLinks"
    private let defaults: UserDefaults
    private var links: [String: CachedCalendarLink]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        links = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode([String: CachedCalendarLink].self, from: $0) }
            ?? [:]
    }

    func state(occurrenceID: String, fingerprint: String, isCancelled: Bool) -> CalendarLinkState {
        if isCancelled { return .cancelled }
        guard let link = links[occurrenceID] else { return .notAdded }
        return link.fingerprint == fingerprint ? .linked : .updated
    }

    func link(for occurrenceID: String) -> CachedCalendarLink? {
        links[occurrenceID]
    }

    func record(occurrenceID: String, eventIdentifier: String?, fingerprint: String) {
        links[occurrenceID] = CachedCalendarLink(
            occurrenceID: occurrenceID,
            eventIdentifier: eventIdentifier,
            fingerprint: fingerprint
        )
        if let data = try? JSONEncoder().encode(links) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
