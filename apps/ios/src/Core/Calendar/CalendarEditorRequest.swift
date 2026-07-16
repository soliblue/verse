import EventKit

struct CalendarEditorRequest: Identifiable {
    let id = UUID()
    let event: EKEvent
    let occurrenceID: String
    let fingerprint: String
}
