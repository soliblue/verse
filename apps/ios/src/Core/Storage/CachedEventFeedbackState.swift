import Foundation
import SwiftData

@Model
final class CachedEventFeedbackState {
    @Attribute(.unique) var key: String
    var eventID: String
    var occurrenceID: String?
    var interested: Bool
    var going: Bool
    var attended: Bool
    var loved: Bool
    var dismissed: Bool
    var updatedAt: Date

    init(eventID: String, occurrenceID: String?) {
        key = Self.key(eventID: eventID, occurrenceID: occurrenceID)
        self.eventID = eventID
        self.occurrenceID = occurrenceID
        interested = false
        going = false
        attended = false
        loved = false
        dismissed = false
        updatedAt = Date()
    }

    static func key(eventID: String, occurrenceID: String?) -> String {
        "\(eventID):\(occurrenceID ?? "event")"
    }
}
