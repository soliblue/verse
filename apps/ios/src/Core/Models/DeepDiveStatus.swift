enum DeepDiveStatus: String, Codable, Hashable {
    case notRequested = "not_requested"
    case queued
    case ready
    case failed
}
