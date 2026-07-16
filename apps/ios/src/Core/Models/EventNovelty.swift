enum EventNovelty: String, Codable, Hashable {
    case new
    case update = "meaningful_update"
    case finalChance = "final_chance"
    case previouslyReported = "previously_reported"
}
