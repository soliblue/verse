#if VERSE_APP || VERSE_WIDGET
import AppIntents

@available(iOS 18.0, *)
nonisolated struct ToggleDictationIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle dictation"
    static let description = IntentDescription("Start speaking, or stop and transcribe on your private server.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @MainActor
    func perform() async throws -> some IntentResult {
        #if VERSE_APP
        let result = await Task { try await TranscriptionStore.shared.toggleSystemDictation() }.result
        if case .failure(let failure) = result {
            await TranscriptionStore.shared.reportFailure(failure)
        }
        try result.get()
        #endif
        return .result()
    }
}
#endif
