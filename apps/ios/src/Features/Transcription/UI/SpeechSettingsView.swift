import SwiftUI
import AVFoundation
import UserNotifications

struct SpeechSettingsView: View {
    let store: TranscriptionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedModel = SpeechSelection.current.modelChoice
    @State private var modelsPresented = false
    @State private var writingEnabled = VerseBridge.writingEnabled
    @State private var style = TranscriptStyle(rawValue: VerseBridge.writingStyle) ?? .original
    @State private var customPrompt = VerseBridge.customWritingPrompt
    @State private var token = VerseBridge.token
    @State private var language = VerseBridge.language
    @State private var connected = false
    @State private var checking = false
    @State private var sessionDuration = VerseBridge.sessionDuration
    @State private var typingKeyboard = VerseBridge.typingKeyboardEnabled
    @State private var keyboardConfirmed = VerseBridge.keyboardSetupConfirmed
    @State private var microphoneAllowed = AVAudioApplication.shared.recordPermission == .granted
    @AppStorage("verse.completionNotifications") private var notifications = false
    private let green = Color(red: 0, green: 0.39, blue: 0.22)
    private let ink = Color(red: 0.12, green: 0.16, blue: 0.10)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { modelsPresented = true } label: {
                        HStack {
                            Text("Model").foregroundStyle(ink)
                            Spacer()
                            Text(selectedModel.title)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .frame(minHeight: 28)
                    }
                    .accessibilityIdentifier("speech-model-picker")
                    .disabled(busy)
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
                .listRowBackground(Color.clear)

                SetupSection(
                    title: "Apple Intelligence", identifier: "apple-intelligence",
                    isOn: $writingEnabled, isAvailable: store.writing.availability.isAvailable,
                    helper: store.writing.availability.isAvailable ? nil : store.writing.availability.message
                ) {
                    if store.writing.availability.isAvailable, writingEnabled {
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
                    }
                }
                .onChange(of: writingEnabled) { _, value in VerseBridge.writingEnabled = value }
                .listRowBackground(Color.clear)
                .disabled(busy)

                if !selectedModel.onDevice {
                    Section {
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
                                    if checking { ProgressView() }
                                    else { Image(systemName: connected ? "checkmark.circle.fill" : "arrow.clockwise") }
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
                    .listRowBackground(Color.clear)
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
                .listRowBackground(Color.clear)

                SetupSection(
                    title: "Typing keyboard", identifier: "typing-keyboard",
                    isOn: $typingKeyboard, isAvailable: keyboardConfirmed,
                    helper: keyboardConfirmed ? "Manage Verse in iPhone Settings." : "Add Verse in iPhone Settings, allow Full Access, then open it once."
                ) {
                    EmptyView()
                }
                .onChange(of: typingKeyboard) { _, value in VerseBridge.typingKeyboardEnabled = value }
                .listRowBackground(Color.clear)

                Section {
                    if !microphoneAllowed {
                        Button("Allow microphone") {
                            store.perform { microphoneAllowed = await AVAudioApplication.requestRecordPermission() }
                        }
                    }
                    Picker("Keep microphone ready", selection: $sessionDuration) {
                        Text("5 minutes").tag(300.0)
                        Text("15 minutes").tag(900.0)
                        Text("60 minutes").tag(3600.0)
                    }
                    .onChange(of: sessionDuration) { _, value in VerseBridge.sessionDuration = value }
                }
                .listRowBackground(Color.clear)
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
            .sheet(isPresented: $modelsPresented) {
                SpeechModelPicker(engine: store.localEngine, selection: SpeechSelection.current) { selection in
                    selectedModel = selection.modelChoice
                    VerseBridge.onDeviceTranscriptionEnabled = selection.onDevice
                    if selection.onDevice { VerseBridge.localModel = selection.model }
                    else { VerseBridge.model = selection.model }
                }
            }
            .task { refreshAvailability() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshAvailability() }
            }
        }
        .presentationBackground { Image("CitrusPaper").resizable().scaledToFill() }
    }

    private var busy: Bool { store.recorder.isRecording || store.isUploading || store.isStartingRecording }

    private func refreshAvailability() {
        store.writing.refreshAvailability()
        microphoneAllowed = AVAudioApplication.shared.recordPermission == .granted
        keyboardConfirmed = VerseBridge.keyboardSetupConfirmed
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            keyboardConfirmed = ProcessInfo.processInfo.arguments.contains("--keyboard-setup-confirmed")
        }
        #endif
    }
}

private struct SetupSection<Content: View>: View {
    let title: String
    let identifier: String
    @Binding var isOn: Bool
    let isAvailable: Bool
    let helper: String?
    @ViewBuilder let content: () -> Content
    @State private var pulse: UUID?
    @State private var highlighted = false
    #if DEBUG
    @State private var highlightStartedAt = 0.0
    @State private var highlightEndedAt = 0.0
    #endif
    private let green = Color(red: 0, green: 0.39, blue: 0.22)

    var body: some View {
        Section {
            Toggle(title, isOn: Binding(
                get: { isAvailable && isOn },
                set: { value in
                    if isAvailable { isOn = value }
                    else { pulse = UUID() }
                }
            ))
            .accessibilityIdentifier(identifier + "-toggle")
            .accessibilityHint(isAvailable ? "" : "Setup required. Tap to highlight the instructions below.")
            content()
        } footer: {
            if let helper {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Text(helper)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(highlighted ? green : Color.secondary)
                        .shadow(color: highlighted ? green.opacity(0.3) : .clear, radius: 5)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier + "-setup")
                .accessibilityValue(highlightAccessibilityValue)
            }
        }
        .task(id: pulse) {
            guard pulse != nil else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                highlighted = true
                #if DEBUG
                highlightStartedAt = Date().timeIntervalSince1970
                highlightEndedAt = 0
                #endif
            }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                highlighted = false
                #if DEBUG
                highlightEndedAt = Date().timeIntervalSince1970
                #endif
            }
        }
    }

    private var highlightAccessibilityValue: String {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            return "pulse:\(highlightStartedAt):\(highlightEndedAt):\(highlighted ? 1 : 0)"
        }
        #endif
        return highlighted ? "Highlighted" : ""
    }
}
