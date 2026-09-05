import Foundation

nonisolated enum DictationInsertionPolicy {
    static func canInsert(transcriptID: String, text: String, insertedID: String) -> Bool {
        !transcriptID.isEmpty && !text.isEmpty && transcriptID != insertedID
    }

    static func canAutomaticallyInsert(transcriptID: String, text: String, insertedID: String, requestedID: String, readyAt: Double, now: Double) -> Bool {
        canInsert(transcriptID: transcriptID, text: text, insertedID: insertedID)
            && requestedID == transcriptID && now >= readyAt && now - readyAt < 120
    }
}
