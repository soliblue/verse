import AVFoundation
import Observation

@MainActor
@Observable
final class TranscriptPlayback: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private var player: AVAudioPlayer?
    private var recordingID: String?
    private var generation = 0
    private weak var store: TranscriptionStore?

    func toggle(_ item: Transcription, using store: TranscriptionStore) async throws {
        guard !store.recorder.isActive, !isLoading else { return }
        self.store = store
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }
        isLoading = true
        let currentGeneration = generation
        defer { isLoading = false }
        if recordingID != item.recordingKey || player == nil {
            let url = try await store.audio(for: item)
            guard generation == currentGeneration, !store.recorder.isActive else { return }
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            recordingID = item.recordingKey
        }
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        isPlaying = player?.play() == true
    }

    func stop() {
        generation += 1
        player?.stop()
        isPlaying = false
        if player != nil, store?.recorder.isActive != true, store?.isStartingRecording != true {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        player = nil
        recordingID = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.isPlaying = false }
    }
}
