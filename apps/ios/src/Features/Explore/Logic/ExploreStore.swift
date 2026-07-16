import Foundation
import Observation

@MainActor
@Observable
final class ExploreStore {
    private(set) var payload: ExplorePayload?
    private(set) var isLoading = false
    private(set) var statusMessage: String?
    var mode = ExploreMode.list
    var selectedDate = Date()

    var events: [EventItem] {
        Array(
            (payload?.featuredEvents ?? [])
                .filter { event in
                    event.occurrence.state != .ended
                        && event.occurrence.state != .cancelled
                        && (event.occurrence.endDate ?? event.occurrence.startDate ?? .distantFuture)
                            >= Date()
                }
                .prefix(12)
        )
    }

    var sections: [EventSection] {
        let calendar = EventDateFormatting.calendar
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let weekend = calendar.nextWeekend(startingAfter: today)
        var groups: [String: [EventItem]] = [:]
        for event in events {
            guard let start = event.occurrence.startDate else { continue }
            let day = calendar.startOfDay(for: start)
            let title: String
            if day == today {
                title = "Tonight"
            } else if day == tomorrow {
                title = "Tomorrow"
            } else if weekend?.contains(start) == true {
                title = "This weekend"
            } else {
                title = "Later"
            }
            groups[title, default: []].append(event)
        }
        return ["Tonight", "Tomorrow", "This weekend", "Later"].compactMap { title in
            guard let events = groups[title], !events.isEmpty else { return nil }
            return EventSection(title: title, events: events)
        }
    }

    func load(repository: ExploreRepository, configuration: ServerConfiguration) async {
        isLoading = payload == nil
        payload = repository.local()
        isLoading = false
        if configuration.isConfigured { await refresh(repository: repository) }
        if payload == nil { statusMessage = "Explore is not available offline yet." }
    }

    func refresh(repository: ExploreRepository) async {
        if let fresh = await repository.refresh() {
            payload = fresh
            statusMessage = nil
        } else if payload != nil {
            statusMessage = "Showing the downloaded Explore list."
        }
    }
}
