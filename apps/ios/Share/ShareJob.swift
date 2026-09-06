import Foundation

struct ShareJob: Decodable {
    let id: String
    let state: String
    let text: String?
    let error: String?
    let detectedLanguage: String?

    enum CodingKeys: String, CodingKey {
        case id, state, text, error
        case detectedLanguage = "detected_language"
    }
}
