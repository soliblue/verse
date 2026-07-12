struct HealthResponse: Codable {
    let status: String
    let database: String
    let currentEditionID: String?

    enum CodingKeys: String, CodingKey {
        case status
        case database
        case currentEditionID = "current_edition_id"
    }
}
