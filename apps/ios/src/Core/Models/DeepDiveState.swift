struct DeepDiveState: Codable, Hashable {
    let status: DeepDiveStatus
    let requestedAt: String?
    let title: String?
    let body: String?
    let citations: [Citation]

    static let empty = DeepDiveState(
        status: .notRequested,
        requestedAt: nil,
        title: nil,
        body: nil,
        citations: []
    )

    enum CodingKeys: String, CodingKey {
        case status
        case requestedAt = "requested_at"
        case title
        case body
        case citations
    }
}
