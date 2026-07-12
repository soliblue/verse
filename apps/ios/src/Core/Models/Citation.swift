import Foundation

struct Citation: Codable, Hashable, Identifiable {
    let title: String
    let url: URL
    let sourceName: String
    let publishedAt: String?

    var id: String { url.absoluteString }

    enum CodingKeys: String, CodingKey {
        case title
        case url
        case sourceName = "source_name"
        case publishedAt = "published_at"
    }
}
