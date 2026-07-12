import Foundation
import SwiftData

@Model
final class CachedEdition {
    @Attribute(.unique) var id: String
    var date: String
    var title: String
    var dek: String
    var generatedAt: String
    var itemCount: Int
    var payload: Data
    var fetchedAt: Date
    var isCurrent: Bool

    init(edition: EditionPayload, payload: Data, fetchedAt: Date, isCurrent: Bool) {
        id = edition.id
        date = edition.date
        title = edition.title
        dek = edition.dek
        generatedAt = edition.generatedAt
        itemCount = edition.items.count
        self.payload = payload
        self.fetchedAt = fetchedAt
        self.isCurrent = isCurrent
    }
}
