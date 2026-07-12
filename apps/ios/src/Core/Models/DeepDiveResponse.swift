struct DeepDiveResponse: Codable {
    let storyID: String
    let deepDive: DeepDiveState

    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
        case deepDive = "deep_dive"
    }
}
