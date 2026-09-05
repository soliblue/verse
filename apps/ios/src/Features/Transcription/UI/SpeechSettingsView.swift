import SwiftUI
import AVFoundation
import UserNotifications

struct SpeechSettingsView: View {
    let store: TranscriptionStore
    @Environment(\.dismiss) private var dismiss
    @State private var token = VerseBridge.token
    @State private var model = VerseBridge.model
    @State private var language = VerseBridge.language
    @State private var connectionStatus = ""
    @State private var checking = false
    @State private var sessionDuration = VerseBridge.sessionDuration
    @State private var microphoneAllowed = AVAudioApplication.shared.recordPermission == .granted
    @AppStorage("verse.completionNotifications") private var notifications = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Device token", text: $token)
                        .textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .onChange(of: token) { _, value in VerseBridge.token = value.trimmingCharacters(in: .whitespacesAndNewlines) }
                    Button(checking ? "Checking…" : "Check connection") {
                        checking = true
                        store.perform {
                            defer { checking = false }
                            try await store.checkConnection()
                            connectionStatus = "Connected"
                        }
                    }.disabled(checking)
                    if !connectionStatus.isEmpty { Label(connectionStatus, systemImage: "checkmark.circle").foregroundStyle(.secondary) }
                    if let error = store.error { Text(error).font(.footnote).foregroundStyle(.red) }
                } footer: { Text("Connected to verse.soli.blue. Your token stays in this device’s Keychain.") }

                Section {
                    Picker("Model", selection: $model) {
                        Text("Small · faster").tag("small")
                        Text("Medium · balanced").tag("medium")
                        Text("Large · more accurate").tag("large-v3")
                    }
                    .onChange(of: model) { _, value in VerseBridge.model = value }
                    Picker("Language", selection: $language) {
                        Text("Detect automatically").tag("auto")
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
                } footer: { Text("Whisper runs on your private server. Larger models take longer. Recordings and transcripts stay there until you delete them.") }

                Section {
                    if !microphoneAllowed {
                        Button("Allow microphone") {
                            store.perform {
                                microphoneAllowed = await AVAudioApplication.requestRecordPermission()
                            }
                        }
                    }
                    if #available(iOS 18.0, *) {
                        Text("Add Verse’s Dictate control in Control Center. Or assign the Toggle dictation shortcut to your Action Button. Tap once to speak, again to transcribe, without opening Verse.")
                    }
                    Text("Add Verse in iPhone Settings → General → Keyboard → Keyboards → Add New Keyboard. Then enable Allow Full Access for Verse.")
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    Picker("Keep microphone ready", selection: $sessionDuration) {
                        Text("5 minutes").tag(300.0)
                        Text("15 minutes").tag(900.0)
                        Text("60 minutes").tag(3600.0)
                    }
                    .onChange(of: sessionDuration) { _, value in VerseBridge.sessionDuration = value }
                    Button("Start keyboard session") {
                        store.perform { try await store.activateKeyboard(); dismiss() }
                    }
                } header: { Text("Keyboard") } footer: {
                    Text("The microphone stays on while the session is ready; only speech between Speak and Stop is saved. End the session from its Live Activity to turn the microphone off. Select the Verse keyboard to receive text automatically. Secure fields may require Apple’s keyboard. Background controls require iOS 18 or later and Live Activities enabled.")
                }

                Section {
                    Toggle("Completion notification", isOn: $notifications)
                        .onChange(of: notifications) { _, enabled in
                            if enabled {
                                store.perform {
                                    notifications = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                                }
                            }
                        }
                } footer: { Text("Notifies when Verse can check a finished job in the background. If iOS suspends the app, the result appears when you reopen it.") }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
