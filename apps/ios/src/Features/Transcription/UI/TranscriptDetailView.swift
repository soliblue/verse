import AVFoundation
import SwiftUI

struct TranscriptDetailView: View {
    let store: TranscriptionStore
    let id: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var player: AVAudioPlayer?
    @State private var loadingAudio = false
    @State private var confirmingDelete = false

    private var item: Transcription? { store.items.first { $0.id == id } }

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: 24) {
                    Text(item.date, format: .dateTime.month(.wide).day().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                    if item.isPending {
                        ProgressView(item.state == "queued" ? "Waiting to transcribe…" : "Transcribing…")
                            .frame(maxWidth: .infinity).padding(.top, 80)
                    } else if item.state == "failed" {
                        ContentUnavailableView("Could not transcribe", systemImage: "exclamationmark.circle", description: Text(item.error ?? "Try uploading this recording again."))
                    } else {
                        Text(item.text?.isEmpty == false ? item.text! : "No speech detected.")
                            .font(.title3).lineSpacing(7).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("transcript-text")
                    }
                }
                .padding(24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let item, let text = item.text, !text.isEmpty {
                    Button {
                        UIPasteboard.general.string = text
                        copied = true
                    } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
                    .accessibilityLabel(copied ? "Copied" : "Copy transcript")
                    ShareLink(item: text).accessibilityLabel("Share transcript")
                }
                Menu {
                    Button("Play recording", systemImage: "play") {
                        loadingAudio = true
                        store.perform {
                            defer { loadingAudio = false }
                            let url = try await store.api.audio(id)
                            try AVAudioSession.sharedInstance().setCategory(.playback)
                            try AVAudioSession.sharedInstance().setActive(true)
                            player = try AVAudioPlayer(contentsOf: url)
                            player?.play()
                        }
                    }.disabled(loadingAudio || store.recorder.isActive)
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("Recording actions")
            }
        }
        .confirmationDialog("Delete this recording and transcript?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let item { store.perform { try await store.delete(item); dismiss() } }
            }
        }
        .onDisappear {
            player?.stop()
            if player != nil { try? AVAudioSession.sharedInstance().setActive(false) }
        }
    }
}
