import Foundation
import SwiftData

@Model
final class CachedTopics {
    @Attribute(.unique) var key: String
    var payload: Data
    var fetchedAt: Date
    var needsSync = false
    var revision = 0

    init(payload: Data, fetchedAt: Date, needsSync: Bool, revision: Int) {
        key = "topics"
        self.payload = payload
        self.fetchedAt = fetchedAt
        self.needsSync = needsSync
        self.revision = revision
    }
}
