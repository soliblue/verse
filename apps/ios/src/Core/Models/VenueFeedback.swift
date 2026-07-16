struct VenueFeedback: Codable, Hashable {
    let venueID: String
    let kind: VenueFeedbackKind
    let value: Bool

    enum CodingKeys: String, CodingKey {
        case venueID = "venue_id"
        case kind
        case value
    }
}
