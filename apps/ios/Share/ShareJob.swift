import Foundation

struct ShareJob: Decodable {
    let id: String
    let state: String
    let text: String?
    let error: String?
}
