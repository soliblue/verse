struct EventFeedback: Codable, Hashable {
    let eventID: String
    let occurrenceID: String?
    let kind: EventFeedbackKind
    let value: Bool

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case occurrenceID = "occurrence_id"
        case kind
        case value
    }
}
