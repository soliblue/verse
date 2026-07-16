import Foundation

struct EventItem: Codable, Hashable, Identifiable {
    let id: String
    let seriesID: String?
    let title: String
    let description: String
    let categories: [String]
    let whySelected: String
    let organizer: String?
    let occurrence: EventOccurrence
    let venue: Venue
    let bookingURL: URL?
    let officialURL: URL
    let sourceName: String
    let checkedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case seriesID = "series_id"
        case title
        case description
        case categories
        case whySelected = "why_selected"
        case organizer
        case occurrence
        case venue
        case bookingURL = "booking_url"
        case officialURL = "official_url"
        case sourceName = "source_name"
        case checkedAt = "checked_at"
    }
}
