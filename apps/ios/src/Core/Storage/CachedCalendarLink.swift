import Foundation
import SwiftData

@Model
final class CachedCalendarLink {
    @Attribute(.unique) var occurrenceID: String
    var eventIdentifier: String?
    var fingerprint: String
    var updatedAt: Date

    init(occurrenceID: String, eventIdentifier: String?, fingerprint: String) {
        self.occurrenceID = occurrenceID
        self.eventIdentifier = eventIdentifier
        self.fingerprint = fingerprint
        updatedAt = Date()
    }
}
