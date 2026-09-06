import SwiftUI
import AVFoundation
import UserNotifications

struct SpeechSettingsView: View {
    let store: TranscriptionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var onDevice = VerseBridge.onDeviceTranscriptionEnabled
    @State private var localModel = VerseBridge.localModel
    @State private var style = TranscriptStyle(rawValue: VerseBridge.writingStyle) ?? .original
    @State private var customPrompt = VerseBridge.customWritingPrompt
    @State private var removingModel = false
    @State private var token = VerseBridge.token
    @State private var model = VerseBridge.model
    @State private var language = VerseBridge.language
    @State private var connected = false
    @State private var checking = false
    @State private var sessionDuration = VerseBridge.sessionDuration
    @State private var typingKeyboard = VerseBridge.typingKeyboardEnabled
    @State private var microphoneAllowed = AVAudioApplication.shared.recordPermission == .granted
    @AppStorage("verse.completionNotifications") private var notifications = false
    private let cream = Color(red: 1, green: 0.95, blue: 0.79)
    private let green = Color(red: 0, green: 0.39, blue: 0.22)
    private let ink = Color(red: 0.12, green: 0.16, blue: 0.10)

    var body: some View {
        NavigationStack {
            Form {
                Section("Transcription") {
                    Picker("Transcribe with", selection: $onDevice) {
                        Text("iPhone").tag(true)
                        Text("Server").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("transcription-engine")
                    .onChange(of: onDevice) { _, value in VerseBridge.onDeviceTranscriptionEnabled = value }
                    .disabled(busy)
                    if onDevice {
                        Picker("Model", selection: $localModel) {
                            ForEach(LocalSpeechEngine.modelChoices) { choice in Text(choice.name).tag(choice.id) }
                        }
                        .accessibilityIdentifier("local-model-picker")
                        .onChange(of: localModel) { _, value in VerseBridge.localModel = value }
                        .disabled(busy)
                        modelDownload
                    } else {
                        Picker("Model", selection: $model) {
                            Text("Small").tag("small")
                            Text("Medium").tag("medium")
                            Text("Large").tag("large-v3")
                        }
                        .onChange(of: model) { _, value in VerseBridge.model = value }
                        .disabled(busy)
                    }
                    Picker("Language", selection: $language) {
                        Text("Automatic").tag("auto")
                        Text("English").tag("en")
                        Text("Arabic").tag("ar")
                        Text("German").tag("de")
                        Text("French").tag("fr")
                        Text("Spanish").tag("es")
                        Text("Italian").tag("it")
                        Text("Portuguese").tag("pt")
                        Text("Turkish").tag("tr")
                        Text("Chinese").tag("zh")
                        Text("Japanese").tag("ja")
                        Text("Korean").tag("ko")
                        Text("Russian").tag("ru")
                        Text("Hindi").tag("hi")
                    }
                    .onChange(of: language) { _, value in VerseBridge.language = value }
                    .disabled(busy)
                }
                .listRowBackground(cream)

                Section {
                    if store.writing.availability.isAvailable {
                        Picker("Style", selection: $style) {
                            ForEach(TranscriptStyle.allCases, id: \.self) { value in Text(value.title).tag(value) }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("writing-style-picker")
                        .onChange(of: style) { _, value in VerseBridge.writingStyle = value.rawValue }
                        if style == .custom {
                            TextField("Your writing instruction", text: $customPrompt, axis: .vertical)
                                .lineLimit(3...6)
                                .accessibilityIdentifier("custom-writing-prompt")
                                .onChange(of: customPrompt) { _, value in
                                    customPrompt = String(value.prefix(500))
                                    VerseBridge.customWritingPrompt = customPrompt
                                }
                        }
                    } else {
                        Label(store.writing.availability.title, systemImage: "wand.and.stars")
                            .accessibilityIdentifier("writing-unavailable")
                        if store.writing.availability.canOpenSettings {
                            Button("Open Settings", systemImage: "arrow.up.right") { openSettings() }
                                .accessibilityIdentifier("apple-intelligence-settings")
                        }
                    }
                } header: {
                    Text("Writing")
                } footer: {
                    Text(store.writing.availability.message)
                }
                .listRowBackground(cream)
                .disabled(busy)

                if !onDevice {
                    Section("Server") {
                    HStack {
                        SecureField("Device token", text: $token)
                            .textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
                            .onChange(of: token) { _, value in
                                VerseBridge.token = value.trimmingCharacters(in: .whitespacesAndNewlines)
                                connected = false
                            }
                        Button {
                            checking = true
                            connected = false
                            store.perform {
                                defer { checking = false }
                                try await store.checkConnection()
                                connected = true
                            }
                        } label: {
                            Group {
                                if checking {
                                    ProgressView()
                                } else {
                                    Image(systemName: connected ? "checkmark.circle.fill" : "arrow.clockwise")
                                }
                            }
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                        .disabled(checking)
                        .accessibilityLabel("Check connection")
                        .accessibilityValue(checking ? "Checking" : (connected ? "Connected" : "Not checked"))
                    }
                    if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
                    }
                    .listRowBackground(cream)
                }

                Section {
                    Toggle("Notify when ready", isOn: $notifications)
                        .onChange(of: notifications) { _, enabled in
                            if enabled {
                                store.perform {
                                    notifications = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                                }
                            }
                        }
                }
                .listRowBackground(cream)

                Section {
                    Toggle("Typing keyboard", isOn: $typingKeyboard)
                        .onChange(of: typingKeyboard) { _, enabled in VerseBridge.typingKeyboardEnabled = enabled }
                    if !microphoneAllowed {
                        Button("Allow microphone") {
                            store.perform {
                                microphoneAllowed = await AVAudioApplication.requestRecordPermission()
                            }
                        }
                    }
                    Button {
                        openSettings()
                    } label: {
                        HStack {
                            Label("iPhone Settings", systemImage: "keyboard")
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.footnote)
                        }
                    }
                    Picker("Keep microphone ready", selection: $sessionDuration) {
                        Text("5 minutes").tag(300.0)
                        Text("15 minutes").tag(900.0)
                        Text("60 minutes").tag(3600.0)
                    }
                    .onChange(of: sessionDuration) { _, value in VerseBridge.sessionDuration = value }
                }
                .listRowBackground(cream)
            }
            .scrollContentBackground(.hidden)
            .background { Image("CitrusPaper").resizable().scaledToFill().ignoresSafeArea() }
            .foregroundStyle(ink)
            .tint(green)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
                        .accessibilityLabel("Done")
                }
            }
            .task { store.writing.refreshAvailability() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    store.writing.refreshAvailability()
                    microphoneAllowed = AVAudioApplication.shared.recordPermission == .granted
                }
            }
            .onChange(of: store.localEngine.installedModelIDs) { _, value in
                VerseBridge.localInstalledModels = value.sorted().joined(separator: ",")
            }
            .confirmationDialog("Remove this downloaded model? Your recordings stay saved.", isPresented: $removingModel, titleVisibility: .visible) {
                Button("Remove model", role: .destructive) { store.perform { try await store.localEngine.delete(localModel) } }
            }
        }
    }

    private var busy: Bool { store.recorder.isRecording || store.isUploading || store.isStartingRecording }

    @ViewBuilder
    private var modelDownload: some View {
        if let downloading = store.localEngine.downloadingModelID {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Downloading \(LocalSpeechEngine.modelChoices.first { $0.id == downloading }?.name ?? downloading)")
                        .font(.subheadline)
                    ProgressView(value: store.localEngine.downloadProgress)
                }
                Button { store.localEngine.cancelDownload() } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                    .buttonStyle(.borderless).accessibilityLabel("Cancel model download")
            }
        } else if store.localEngine.installedModelIDs.contains(localModel) {
            HStack {
                Label("Ready on this iPhone", systemImage: "checkmark.circle")
                    .font(.subheadline)
                Spacer()
                Button { removingModel = true } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                    .buttonStyle(.borderless).accessibilityLabel("Remove downloaded model")
                    .disabled(busy || store.localEngine.isBusy)
            }
        } else if let selected = LocalSpeechEngine.modelChoices.first(where: { $0.id == localModel }) {
            Button {
                store.localEngine.download(localModel)
            } label: {
                HStack {
                    Label("Download \(selected.name)", systemImage: "arrow.down.circle")
                    Spacer()
                    Text("~\(selected.approximateDownload)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("download-local-model")
            .disabled(busy || store.localEngine.isBusy)
        }
        if let error = store.localEngine.error { Text(error).font(.footnote).foregroundStyle(.red) }
        Text("Recordings and files imported in Verse stay on this iPhone. The share extension uses your server.")
            .font(.footnote).foregroundStyle(.secondary)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
