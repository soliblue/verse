#if VERSE_APP || VERSE_WIDGET
import AppIntents

nonisolated struct EndDictationSessionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End dictation session"
    static let description = IntentDescription("Turn off the microphone and finish your Verse session.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        #if VERSE_APP
        let result = await Task { try await TranscriptionStore.shared.endSession() }.result
        if case .failure(let failure) = result {
            await TranscriptionStore.shared.reportFailure(failure)
        }
        try result.get()
        #endif
        return .result()
    }
}
#endif
