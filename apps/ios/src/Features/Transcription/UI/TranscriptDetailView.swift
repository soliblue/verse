import SwiftUI

struct TranscriptDetailView: View {
    let store: TranscriptionStore
    let id: String
    @Environment(\.dismiss) private var dismiss
    @State private var regenerationLanguage: String?
    @State private var copied = false
    @State private var playback = TranscriptPlayback()
    @State private var confirmingDelete = false
    @State private var showOriginal = false
    private let green = Color(red: 0, green: 0.39, blue: 0.22)
    private let ink = Color(red: 0.12, green: 0.16, blue: 0.10)

    private var versions: [Transcription] { store.versions(for: id) }
    private var item: Transcription? { store.preferredVersion(for: id) }
    private var text: String? { showOriginal ? item?.originalText : item?.text }
    private var language: String { regenerationLanguage ?? item?.language ?? "auto" }
    private var languageName: String {
        language == "auto" ? "Automatic" : Locale(identifier: "en").localizedString(forLanguageCode: language)?.capitalized ?? language.uppercased()
    }
    private var choices: [SpeechModelChoice] {
        SpeechModelChoice.all.filter { $0.onDevice || store.models.contains($0.model) }
    }
    private var busy: Bool {
        store.regeneration.isRunning || store.isRerunning || store.isUploading || store.recorder.isRecording || store.isStartingRecording
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let item {
                    VStack(alignment: .leading, spacing: 18) {
                        if store.regeneration.recordingID == item.recordingKey,
                           let selection = store.regeneration.selection,
                           store.localEngine.downloadingModelID == selection.model {
                            HStack(spacing: 12) {
                                ProgressView(value: store.localEngine.downloadProgress) {
                                    Text(selection.modelChoice.title).font(.caption)
                                }
                                .accessibilityIdentifier("transcript-model-download")
                                Button { store.regeneration.cancelDownload(using: store.localEngine) } label: {
                                    Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Cancel model download")
                            }
                        }
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
                        HStack(spacing: 5) {
                            Text(item.languageLabel)
                            Text("·")
                            if let duration = item.durationSeconds {
                                Text(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))
                                Text("·")
                            }
                            Text(item.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("transcript-metadata")
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
                ToolbarItemGroup(placement: .bottomBar) { actions }
            }
            .confirmationDialog("Delete this recording and all its transcripts?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let item { store.perform { try await store.delete(item); dismiss() } }
                }
            }
            .alert("Verse", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
            .onChange(of: item?.id) { _, _ in
                regenerationLanguage = nil
                showOriginal = false
                copied = false
                playback.stop()
            }
            .onDisappear { playback.stop() }
            .accessibilityIdentifier("transcript-sheet")
        }
    }

    private var versionMenu: some View {
        Menu {
            Section("Versions") {
                ForEach(versions) { version in
                    Button {
                        store.perform { try store.selectVersion(version) }
                    } label: {
                        let title = "\(version.compactModelLabel) · \(version.languageLabel)"
                        if item?.id == version.id {
                            Label(title, systemImage: "checkmark")
                        } else {
                            Text(title)
                        }
                        Text(version.date, format: .dateTime.hour().minute().second())
                    }
                    .accessibilityIdentifier("transcript-version-\(version.id)")
                }
            }
            Section("Regenerate in") { languagePicker }
            Section {
                ForEach(choices.filter { !$0.onDevice || store.localEngine.installedModelIDs.contains($0.model) }) { choice in
                    regenerationButton(choice, download: false)
                }
            }
            if choices.contains(where: { $0.onDevice && !store.localEngine.installedModelIDs.contains($0.model) }) {
                Section("More local models") {
                    ForEach(choices.filter { $0.onDevice && !store.localEngine.installedModelIDs.contains($0.model) }) { choice in
                        regenerationButton(choice, download: true)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(item.map { "\($0.compactModelLabel) · \($0.languageLabel)" } ?? "Transcript")
                    .lineLimit(1).minimumScaleFactor(0.8)
                if store.regeneration.recordingID == item?.recordingKey { ProgressView() }
                else { Image(systemName: "chevron.down").font(.caption.weight(.semibold)) }
            }
            .font(.subheadline)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 6)
        }
        .menuOrder(.fixed)
        .accessibilityIdentifier("transcript-version-picker")
        .accessibilityLabel(item.map { "\($0.compactModelLabel) · \($0.languageLabel)" } ?? "Transcript versions")
    }

    private var languagePicker: some View {
        Picker(languageName, selection: Binding(get: { language }, set: { regenerationLanguage = $0 })) {
            Text("Automatic").tag("auto").accessibilityIdentifier("regeneration-language-auto")
            ForEach(["en", "ar", "de", "fr", "es", "it", "pt", "tr", "zh", "ja", "ko", "ru", "hi"], id: \.self) { code in
                Text(Locale(identifier: "en").localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased())
                    .tag(code)
                    .accessibilityIdentifier("regeneration-language-" + code)
            }
        }
        .pickerStyle(.menu)
        .menuActionDismissBehavior(.disabled)
        .accessibilityIdentifier("transcript-language-picker")
        .disabled(busy)
    }

    private func regenerationButton(_ choice: SpeechModelChoice, download: Bool) -> some View {
        Button {
            guard let item else { return }
            var selection = item.selection.replacingModel(choice)
            selection.language = language
            playback.stop()
            store.perform { try await store.regeneration.run(item, selection: selection, using: store) }
        } label: {
            Label(choice.title, systemImage: download ? "arrow.down.circle" : "arrow.clockwise")
            if download, let size = LocalSpeechEngine.modelChoices.first(where: { $0.id == choice.model })?.approximateDownload {
                Text(size)
            }
        }
        .disabled(busy || (download && (store.localEngine.isBusy || store.localEngine.downloadingModelID != nil)))
        .accessibilityIdentifier("regenerate-model-" + choice.id)
        .accessibilityHint(download ? "Download and regenerate in \(languageName)." : "Regenerate in \(languageName).")
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
