struct Topic: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var kind: TopicKind
    var description: String
    var isEnabled: Bool
    var position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case description
        case isEnabled = "is_enabled"
        case position
    }
}
