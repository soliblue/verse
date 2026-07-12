struct FeedbackResponse: Codable {
    let storyID: String
    let feedback: FeedbackState

    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
        case feedback
    }
}
