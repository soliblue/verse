struct FeedbackState: Codable, Hashable {
    let saved: Bool
    let seen: Bool
    let preference: FeedbackPreference?
    let updatedAt: String?

    static let empty = FeedbackState(saved: false, seen: false, preference: nil, updatedAt: nil)

    enum CodingKeys: String, CodingKey {
        case saved
        case seen
        case preference
        case updatedAt = "updated_at"
    }
}
