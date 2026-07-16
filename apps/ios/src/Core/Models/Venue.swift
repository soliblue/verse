import Foundation

struct Venue: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let neighborhood: String?
    let officialURL: URL
    let whyWatched: String
    let distanceBand: String
    let watchState: VenueWatchState
    let nextEventID: String?
    let calendarURL: URL?

    var distanceLabel: String? {
        guard distanceBand != "unknown" else { return nil }
        return distanceBand.replacingOccurrences(of: "_", with: " ").capitalized
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case latitude
        case longitude
        case neighborhood
        case officialURL = "official_url"
        case whyWatched = "why_watched"
        case distanceBand = "distance_band"
        case watchState = "watch_state"
        case nextEventID = "next_event_id"
        case calendarURL = "calendar_url"
    }
}
