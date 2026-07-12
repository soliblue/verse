struct EditionSummary: Codable, Hashable, Identifiable {
    let id: String
    let date: String
    let title: String
    let dek: String
    let generatedAt: String
    let itemCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case title
        case dek
        case generatedAt = "generated_at"
        case itemCount = "item_count"
    }
}
