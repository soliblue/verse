import SwiftUI
import UniformTypeIdentifiers

struct TranscriptionHubView: View {
    @Bindable var store: TranscriptionStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var settingsPresented = false
    @State private var importing = false

    var body: some View {
        NavigationStack {
            List {
                if !store.isConfigured {
                    Button { settingsPresented = true } label: {
                        Label("Add your device token", systemImage: "key")
                    }
                }
                if let expiry = store.keyboardExpiresAt {
                    HStack {
                        Label("Keyboard ready", systemImage: "keyboard")
                        Spacer()
                        Text(expiry, style: .timer).monospacedDigit().foregroundStyle(.secondary)
                        Button("End") { store.perform { try await store.endSession() } }
                    }
                    .font(.subheadline)
                }
                if !store.pendingAudio.isEmpty {
                    Section("Not uploaded") {
                        ForEach(store.pendingAudio, id: \.self) { url in
                            Button {
                                store.perform { try await store.upload(url) }
                            } label: { Label("Retry recording", systemImage: "arrow.clockwise") }
                            .disabled(store.isUploading)
                            .swipeActions {
                                Button("Delete", role: .destructive) { store.perform { try store.discardPending(url) } }
                                    .disabled(store.isUploading)
                            }
                        }
                    }
                }
                ForEach(store.items) { item in
                    NavigationLink(value: item.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title).font(.body).lineLimit(3).foregroundStyle(.primary)
                            HStack(spacing: 8) {
                                Text(item.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                if item.isPending {
                                    ProgressView().controlSize(.mini)
                                    Text(item.state == "queued" ? "Queued" : "Transcribing")
                                } else if item.state == "failed" {
                                    Text("Failed").foregroundStyle(.red)
                                }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { store.perform { try await store.delete(item) } }
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if store.items.isEmpty && store.pendingAudio.isEmpty && store.isConfigured {
                    ContentUnavailableView {
                        Label("No recordings", systemImage: "waveform")
                    } description: { Text("Record something or share an audio file to Verse.") }
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Verse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Import audio")
                    Button { settingsPresented = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Settings")
                }
            }
            .safeAreaInset(edge: .bottom) { recordingControls }
            .navigationDestination(for: String.self) { id in TranscriptDetailView(store: store, id: id) }
            .refreshable { store.perform { try await store.refresh() } }
            .task { store.perform { try await store.refresh() } }
            .sheet(isPresented: $settingsPresented) { SpeechSettingsView(store: store) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio, .movie, .mpeg4Audio], allowsMultipleSelection: false) { result in
                store.perform {
                    if let url = try result.get().first { try await store.importAudio(url) }
                }
            }
            .alert("Verse", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
            } message: { Text(store.error ?? "") }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.perform { try await store.refresh() } }
            }
            .onOpenURL { url in
                if url.scheme == "verse" {
                    store.perform { try await store.activateKeyboard() }
                } else if url.isFileURL {
                    store.perform { try await store.importAudio(url) }
                }
            }
            .accessibilityIdentifier("transcription-hub")
        }
    }

    private var recordingControls: some View {
        VStack(spacing: 14) {
            if store.recorder.isRecording {
                Text(store.recorder.startedAt, style: .timer).font(.title3.monospacedDigit())
            } else if store.isUploading {
                Text("Uploading…").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 32) {
                Button {
                    store.perform { try await store.activateKeyboard() }
                } label: {
                    Image(systemName: "keyboard").font(.title3).frame(width: 48, height: 48)
                }
                .accessibilityLabel("Activate keyboard")
                .disabled(store.recorder.isRecording || store.isUploading || store.isStartingRecording)
                Button {
                    store.perform { try await store.toggleRecording() }
                } label: {
                    Image(systemName: store.recorder.isRecording ? "stop.fill" : "waveform")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .background(LinearGradient(colors: [.purple, .indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                }
                .accessibilityLabel(store.recorder.isRecording ? "Stop recording" : "Record")
                .disabled(store.isUploading || store.isStartingRecording)
                Color.clear.frame(width: 48, height: 48).accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16).padding(.bottom, 20)
        .background(.regularMaterial)
    }
}
