import SwiftUI
import UniformTypeIdentifiers

struct TranscriptionHubView: View {
    @Bindable var store: TranscriptionStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var settingsPresented = false
    @State private var importing = false
    private let lemon = Color(red: 0.988, green: 0.902, blue: 0.259)
    private let cream = Color(red: 1, green: 0.97, blue: 0.85)
    private let ink = Color(red: 0.12, green: 0.16, blue: 0.10)

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                List {
                    VStack(spacing: 4) {
                        HStack {
                            Text("verse")
                                .font(.system(size: 36, weight: .heavy, design: .rounded).italic())
                                .foregroundStyle(Color(red: 0, green: 0.43, blue: 0.23))
                            Spacer()
                            Button { importing = true } label: {
                                Image(systemName: "square.and.arrow.down")
                                    .frame(width: 48, height: 48).background(cream, in: Circle())
                            }
                            .accessibilityLabel("Import audio")
                            Button { settingsPresented = true } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .frame(width: 48, height: 48).background(cream, in: Circle())
                            }
                            .accessibilityLabel("Settings")
                        }
                        .font(.title3)
                        .buttonStyle(.plain)
                        ZStack {
                            Image("Citrus")
                                .resizable().scaledToFit()
                                .clipShape(Circle())
                                .accessibilityHidden(true)
                            recordingControls
                        }
                        .frame(height: min(geometry.size.width - 32, geometry.size.height * 0.52))
                    }
                    .padding(.vertical, 12)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(lemon)
                    .listRowSeparator(.hidden)
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
                    HStack {
                        Text("Recent").font(.headline)
                        Spacer()
                        Button {
                            store.perform { try await store.activateKeyboard() }
                        } label: {
                            Image(systemName: "keyboard").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Activate keyboard")
                        .disabled(store.recorder.isRecording || store.isUploading || store.isStartingRecording)
                    }
                    .listRowBackground(cream)
                    if store.items.isEmpty && store.pendingAudio.isEmpty {
                        Text("Your recordings will appear here.")
                            .font(.body).foregroundStyle(ink.opacity(0.7))
                            .padding(.vertical, 20)
                            .listRowBackground(cream)
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
                        .listRowBackground(cream)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .background(lemon.ignoresSafeArea())
                .foregroundStyle(ink)
                .toolbar(.hidden, for: .navigationBar)
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
    }

    private var recordingControls: some View {
        Button {
            if store.isConfigured {
                store.perform { try await store.toggleRecording() }
            } else {
                settingsPresented = true
            }
        } label: {
            VStack(spacing: 8) {
                if store.isUploading || store.isStartingRecording {
                    ProgressView().tint(ink)
                } else {
                    Image(systemName: store.recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 36, weight: .medium))
                }
                if store.recorder.isRecording {
                    Text(store.recorder.startedAt, style: .timer)
                        .font(.subheadline.monospacedDigit())
                } else {
                    Text(store.isUploading ? "Uploading" : (store.isStartingRecording ? "Starting" : "Speak"))
                        .font(.headline)
                }
            }
            .foregroundStyle(ink)
            .frame(width: 120, height: 120)
            .background(cream, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.recorder.isRecording ? "Stop recording" : "Record")
        .disabled(store.isUploading || store.isStartingRecording)
    }
}
