struct ExplorePayload: Codable, Hashable, Identifiable {
    let id: String
    let generatedAt: String
    let timezone: String
    let horizonStart: String
    let horizonEnd: String
    let featuredEvents: [EventItem]
    let events: [EventItem]
    let venues: [Venue]
    let calendar: [EventOccurrence]

    var allEvents: [EventItem] { events }

    enum CodingKeys: String, CodingKey {
        case id
        case generatedAt = "generated_at"
        case timezone
        case horizonStart = "horizon_start"
        case horizonEnd = "horizon_end"
        case featuredEvents = "featured_events"
        case events
        case venues
        case calendar
    }
}
