import Foundation
import SwiftData

@Model
final class CachedExplore {
    @Attribute(.unique) var key: String
    var payload: Data
    var fetchedAt: Date

    init(payload: Data, fetchedAt: Date) {
        key = "current"
        self.payload = payload
        self.fetchedAt = fetchedAt
    }
}
