enum APIEndpoint {
    static let today = "v1/edition/today"
    static let editions = "v1/editions"
    static let topics = "v1/topics"
    static let feedback = "v1/feedback"
    static let deepDives = "v1/deep-dives"
    static let health = "health"

    static func edition(_ id: String) -> String { "v1/editions/\(id)" }
}
