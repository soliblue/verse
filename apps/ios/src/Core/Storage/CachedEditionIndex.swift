import Foundation
import SwiftData

@Model
final class CachedEditionIndex {
    @Attribute(.unique) var key: String
    var payload: Data
    var fetchedAt: Date

    init(payload: Data, fetchedAt: Date) {
        key = "editions"
        self.payload = payload
        self.fetchedAt = fetchedAt
    }
}
