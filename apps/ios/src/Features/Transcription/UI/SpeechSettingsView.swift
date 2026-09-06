import SwiftUI
import AVFoundation
import UserNotifications

struct SpeechSettingsView: View {
    let store: TranscriptionStore
    @Environment(\.dismiss) private var dismiss
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

                Section {
                    Picker("Model", selection: $model) {
                        Text("Small").tag("small")
                        Text("Medium").tag("medium")
                        Text("Large").tag("large-v3")
                    }
                    .onChange(of: model) { _, value in VerseBridge.model = value }
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
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
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
        }
    }
}
