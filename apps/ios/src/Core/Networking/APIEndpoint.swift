enum APIEndpoint {
    static let today = "v1/edition/today"
    static let editions = "v1/editions"
    static let topics = "v1/topics"
    static let preferences = "v1/preferences"
    static let feedback = "v1/feedback"
    static let deepDives = "v1/deep-dives"
    static let explore = "v1/explore"
    static let eventFeedback = "v1/event-feedback"
    static let venueFeedback = "v1/venue-feedback"
    static let health = "health"

    static func edition(_ id: String) -> String { "v1/editions/\(id)" }
    static func guidance(_ job: NightjarJob) -> String { "v1/guidance/\(job.rawValue)" }
    static func run(_ job: NightjarJob) -> String { "v1/runs/\(job.rawValue)" }
}
