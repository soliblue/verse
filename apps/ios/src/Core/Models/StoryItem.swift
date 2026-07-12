import Foundation

struct StoryItem: Codable, Hashable, Identifiable {
    let id: String
    let position: Int
    let kind: String
    let topicIDs: [String]
    let title: String
    let summary: String
    let body: String
    let whySelected: String
    let sourceName: String
    let sourceURL: URL
    let publishedAt: String
    let readingMinutes: Int
    let imageURL: URL?
    let citations: [Citation]
    let feedback: FeedbackState?
    let deepDive: DeepDiveState?

    var resolvedFeedback: FeedbackState { feedback ?? .empty }
    var resolvedDeepDive: DeepDiveState { deepDive ?? .empty }

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case kind
        case topicIDs = "topic_ids"
        case title
        case summary
        case body
        case whySelected = "why_selected"
        case sourceName = "source_name"
        case sourceURL = "source_url"
        case publishedAt = "published_at"
        case readingMinutes = "reading_minutes"
        case imageURL = "image_url"
        case citations
        case feedback
        case deepDive = "deep_dive"
    }
}
