import Observation

@MainActor
@Observable
final class TranscriptRegeneration {
    private(set) var selection: SpeechSelection?
    private(set) var recordingID: String?
    private var cancelled = false

    var isRunning: Bool { recordingID != nil }

    func run(_ item: Transcription, selection: SpeechSelection, using store: TranscriptionStore) async throws {
        guard !isRunning else { throw SpeechFailure("Wait for this transcription to finish.") }
        self.selection = selection
        recordingID = item.recordingKey
        cancelled = false
        defer {
            self.selection = nil
            recordingID = nil
        }
        let engine = store.localEngine
        if selection.onDevice, !engine.installedModelIDs.contains(selection.model) {
            guard !engine.isBusy, engine.downloadingModelID == nil || engine.downloadingModelID == selection.model else {
                throw SpeechFailure("Wait for the current model download to finish.")
            }
            engine.download(selection.model)
            while engine.downloadingModelID == selection.model {
                try await Task.sleep(for: .milliseconds(200))
            }
            guard !cancelled else { return }
            if !engine.installedModelIDs.contains(selection.model) {
                if let error = engine.error { throw SpeechFailure(error) }
                return
            }
        }
        try Task.checkCancellation()
        guard !cancelled else { return }
        let version = try await store.transcribeAgain(item, selection: selection)
        try store.selectVersion(version)
    }

    func cancelDownload(using engine: LocalSpeechEngine) {
        guard let selection, selection.onDevice, engine.downloadingModelID == selection.model else { return }
        cancelled = true
        engine.cancelDownload()
    }
}
