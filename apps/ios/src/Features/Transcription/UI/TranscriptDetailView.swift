import SwiftUI

struct TranscriptDetailView: View {
    let store: TranscriptionStore
    let id: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVersionID: String?
    @State private var copied = false
    @State private var playback = TranscriptPlayback()
    @State private var confirmingDelete = false
    @State private var showOriginal = false
    @State private var choosingModel = false
    private let green = Color(red: 0, green: 0.39, blue: 0.22)
    private let ink = Color(red: 0.12, green: 0.16, blue: 0.10)

    private var versions: [Transcription] { store.versions(for: id) }
    private var item: Transcription? { versions.first { $0.id == selectedVersionID } ?? versions.first }
    private var text: String? { showOriginal ? item?.originalText : item?.text }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let item {
                    VStack(alignment: .leading, spacing: 18) {
                        if item.isPending {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 100)
                                .accessibilityLabel("Transcribing")
                        } else if item.state == "failed" {
                            Text(item.error ?? "Could not transcribe this recording.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(text.flatMap { $0.isEmpty ? nil : $0 } ?? "No speech detected.")
                                .font(.title3).lineSpacing(5).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("transcript-text")
                            if let raw = item.writingFallback, let reason = TranscriptRewriteFallback(rawValue: raw) {
                                Text(reason.message).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            Text(item.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                            if let duration = item.durationSeconds {
                                Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                            }
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 22).padding(.vertical, 20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background { Image("CitrusPaper").resizable().scaledToFill().ignoresSafeArea() }
            .foregroundStyle(ink)
            .tint(green)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar, .bottomBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { versionMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { choosingModel = true } label: {
                        if store.isRerunning { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(store.isRerunning || store.isUploading || store.recorder.isRecording || store.isStartingRecording)
                    .accessibilityLabel("Transcribe again")
                    .accessibilityIdentifier("transcribe-again")
                }
                ToolbarItemGroup(placement: .bottomBar) { actions }
            }
            .sheet(isPresented: $choosingModel) {
                if let item {
                    SpeechModelPicker(engine: store.localEngine, selection: item.selection, requiresReadyModel: true) { selection in
                        choosingModel = false
                        playback.stop()
                        store.perform {
                            let result = try await store.transcribeAgain(item, selection: selection)
                            selectedVersionID = result.id
                            showOriginal = false
                            copied = false
                        }
                    }
                }
            }
            .confirmationDialog("Delete this recording and all its transcripts?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let item { store.perform { try await store.delete(item); dismiss() } }
                }
            }
            .alert("Verse", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
            .onDisappear { playback.stop() }
            .accessibilityIdentifier("transcript-sheet")
        }
    }

    private var versionMenu: some View {
        Menu {
            ForEach(versions) { version in
                Button {
                    selectedVersionID = version.id
                    showOriginal = false
                    copied = false
                } label: {
                    if item?.id == version.id {
                        Label(version.modelLabel, systemImage: "checkmark")
                    } else {
                        Text(version.modelLabel)
                    }
                    Text(version.date, format: .dateTime.hour().minute().second())
                }
                .accessibilityIdentifier("transcript-version-\(version.id)")
            }
            Divider()
            Button("Transcribe again…", systemImage: "arrow.clockwise") { choosingModel = true }
                .disabled(store.isRerunning || store.isUploading || store.recorder.isRecording || store.isStartingRecording)
        } label: {
            HStack(spacing: 6) {
                Text(item?.modelLabel ?? "Transcript").lineLimit(1).minimumScaleFactor(0.8)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
            .font(.subheadline)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
        }
        .accessibilityIdentifier("transcript-version-picker")
        .accessibilityLabel(item?.modelLabel ?? "Transcript versions")
    }

    @ViewBuilder
    private var actions: some View {
        if let item {
            Button { store.perform { try await playback.toggle(item, using: store) } } label: {
                if playback.isLoading { ProgressView() }
                else { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill") }
            }
            .disabled(playback.isLoading || store.recorder.isActive)
            .accessibilityLabel(playback.isPlaying ? "Pause recording" : "Play recording")
            Spacer()
            if let text, !text.isEmpty {
                Button {
                    UIPasteboard.general.string = text
                    copied = true
                } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
                .accessibilityLabel(copied ? "Copied" : "Copy transcript")
                Spacer()
                ShareLink(item: text).accessibilityLabel("Share transcript")
                Spacer()
            }
            Menu {
                if item.hasRewrite {
                    Button(showOriginal ? "Show styled text" : "Show original", systemImage: "textformat") { showOriginal.toggle(); copied = false }
                }
                Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
            } label: { Image(systemName: "ellipsis.circle") }
            .accessibilityLabel("Recording actions")
        }
    }
}
