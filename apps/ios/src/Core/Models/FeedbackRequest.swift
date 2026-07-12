struct FeedbackRequest: Codable {
    let storyID: String
    let kind: FeedbackKind
    let value: Bool

    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
        case kind
        case value
    }
}
