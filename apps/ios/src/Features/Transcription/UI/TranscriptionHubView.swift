import SwiftUI
import UniformTypeIdentifiers

struct TranscriptionHubView: View {
    @Bindable var store: TranscriptionStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var settingsPresented = false
    @State private var importing = false
    @State private var returningToKeyboard = false
    private let cream = Color(red: 1, green: 0.95, blue: 0.79)
    private let green = Color(red: 0, green: 0.39, blue: 0.22)
    private let ink = Color(red: 0.12, green: 0.16, blue: 0.10)

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        masthead.padding(.horizontal, 24).padding(.top, 8)
                        ZStack {
                            Image("CitrusHero").resizable().scaledToFit().accessibilityHidden(true)
                            recordingControls
                        }
                        .frame(width: min(geometry.size.width, 520), height: min(geometry.size.width, 520))
                        if returningToKeyboard && store.recorder.isRecording {
                            VStack(spacing: 5) {
                                Text("Listening. Swipe back to your app.").font(.headline)
                                Text("Swipe right along the bottom edge. Tap Stop in the keyboard when done.")
                                    .font(.subheadline)
                            }
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24).padding(.bottom, 16)
                            .accessibilityIdentifier("dictation-return-guidance")
                        }
                        sessionStatus.padding(.horizontal, 24)
                        TranscriptionHistoryView(store: store)
                            .padding(.horizontal, 20).padding(.bottom, 24)
                    }
                    .frame(maxWidth: 560).frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .background {
                    Image("CitrusPaper").resizable().scaledToFill().ignoresSafeArea()
                }
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
                    if phase == .background { returningToKeyboard = false }
                }
                .onOpenURL { url in
                    if url.scheme == "verse" {
                        returningToKeyboard = url.host == "dictate"
                        store.perform {
                            if url.host == "dictate" {
                                try await store.startKeyboardDictation()
                            } else {
                                try await store.activateKeyboard()
                            }
                        }
                    } else if url.isFileURL {
                        store.perform { try await store.importAudio(url) }
                    }
                }
                .accessibilityIdentifier("transcription-hub")
            }
        }
    }

    private var masthead: some View {
        HStack {
            Text("verse")
                .font(.custom("AvenirNext-HeavyItalic", size: 39, relativeTo: .largeTitle))
                .tracking(-2).rotationEffect(.degrees(-8)).foregroundStyle(green)
            Spacer()
            Button { importing = true } label: {
                Image(systemName: "music.note")
                    .foregroundStyle(Color(red: 0.93, green: 0.31, blue: 0.07))
                    .frame(width: 44, height: 44).background(cream, in: Circle())
            }
            .accessibilityLabel("Import audio")
            Button { settingsPresented = true } label: {
                Image(systemName: "gearshape.fill").foregroundStyle(green)
                    .frame(width: 44, height: 44).background(cream, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .font(.system(size: 21, weight: .semibold)).buttonStyle(.plain)
    }

    @ViewBuilder
    private var sessionStatus: some View {
        if !store.isConfigured {
            Button { settingsPresented = true } label: {
                Label("Add your device token", systemImage: "key")
            }
            .padding(.bottom, 16)
        }
        if let expiry = store.keyboardExpiresAt {
            HStack {
                Label("Keyboard ready", systemImage: "keyboard")
                Spacer()
                Text(expiry, style: .timer).monospacedDigit()
                Button("End") { store.perform { try await store.endSession() } }
            }
            .font(.caption).padding(.bottom, 16)
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
            VStack(spacing: 3) {
                if store.isUploading || store.isStartingRecording {
                    ProgressView().tint(ink)
                } else {
                    Image(systemName: store.recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 39, weight: .medium))
                }
                if store.recorder.isRecording {
                    Text(store.recorder.startedAt, style: .timer).font(.subheadline.monospacedDigit())
                } else {
                    Text(store.isUploading ? "Uploading" : (store.isStartingRecording ? "Starting" : "Speak"))
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                }
            }
            .foregroundStyle(ink).frame(width: 100, height: 100).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.recorder.isRecording ? "Stop recording" : "Record")
        .disabled(store.isUploading || store.isStartingRecording)
    }
}
