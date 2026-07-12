struct DeepDiveRequest: Codable {
    let storyID: String

    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
    }
}
