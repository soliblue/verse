import Foundation

struct CachedCalendarLink: Codable, Equatable {
    let occurrenceID: String
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
