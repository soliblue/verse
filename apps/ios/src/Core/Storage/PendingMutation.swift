import Foundation
import SwiftData

@Model
final class PendingMutation {
    @Attribute(.unique) var id: String
    var storyID: String
    var path: String
    var payload: Data
    var createdAt: Date
    var failedAt: Date?
    var failureReason: String?

    init(storyID: String, path: String, payload: Data) {
        id = UUID().uuidString
        self.storyID = storyID
        self.path = path
        self.payload = payload
        createdAt = Date()
        failedAt = nil
        failureReason = nil
    }
}
