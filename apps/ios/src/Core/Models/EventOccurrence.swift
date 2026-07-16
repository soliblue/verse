import Foundation

struct EventOccurrence: Codable, Hashable, Identifiable {
    let id: String
    let eventID: String
    let title: String
    let venueID: String
    let startAt: String
    let endAt: String?
    let doorsAt: String?
    let state: EventState
    let novelty: EventNovelty
    let priceEUR: Double?
    let reducedPriceEUR: Double?
    let isFree: Bool
    let rsvpRequired: Bool
    let soldOut: Bool
    let bookingURL: URL?
    let languages: [String]
    let accessibilityNotes: String?
    let ageLimit: String?
    let outdoor: Bool
    let weatherDependent: Bool

    var startDate: Date? { TimestampParsing.date(startAt) }
    var endDate: Date? { TimestampParsing.date(endAt) }

    var priceLabel: String {
        if isFree { return "Free" }
        guard let priceEUR else { return "Price unknown" }
        return priceEUR.formatted(.currency(code: "EUR").locale(Locale(identifier: "en_DE")))
    }

    var bookingLabel: String {
        if state == .cancelled { return "Cancelled" }
        if soldOut { return "Sold out" }
        if rsvpRequired { return "RSVP" }
        return priceLabel
    }

    func isAttendable(at date: Date = Date()) -> Bool {
        guard !soldOut, state != .cancelled, state != .ended else { return false }
        return (endDate ?? startDate ?? .distantFuture) >= date
    }

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "event_id"
        case title
        case venueID = "venue_id"
        case startAt = "start_at"
        case endAt = "end_at"
        case doorsAt = "doors_at"
        case state
        case novelty
        case priceEUR = "price_eur"
        case reducedPriceEUR = "reduced_price_eur"
        case isFree = "is_free"
        case rsvpRequired = "rsvp_required"
        case soldOut = "sold_out"
        case bookingURL = "booking_url"
        case languages
        case accessibilityNotes = "accessibility_notes"
        case ageLimit = "age_limit"
        case outdoor
        case weatherDependent = "weather_dependent"
    }
}
