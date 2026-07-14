import SwiftUI

struct SettingsView: View {
    let configuration: ServerConfiguration
    let api: APIClient
    let editions: EditionRepository
    let feedback: FeedbackRepository
    let topics: TopicsRepository
    @State private var store: SettingsStore
    @State private var revealSecret = false

    init(
        configuration: ServerConfiguration,
        api: APIClient,
        editions: EditionRepository,
        feedback: FeedbackRepository,
        topics: TopicsRepository
    ) {
        self.configuration = configuration
        self.api = api
        self.editions = editions
        self.feedback = feedback
        self.topics = topics
        _store = State(initialValue: SettingsStore(configuration: configuration))
    }

    var body: some View {
        Form {
            Section {
                TextField("https://verse.example.com", text: $store.serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Server URL")
                HStack {
                    Group {
                        if revealSecret {
                            TextField("Optional device secret", text: $store.deviceSecret)
                        } else {
                            SecureField("Optional device secret", text: $store.deviceSecret)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    Button {
                        revealSecret.toggle()
                    } label: {
                        Image(systemName: revealSecret ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(revealSecret ? "Hide secret" : "Show secret")
                }
                Button("Save connection", systemImage: "checkmark.circle") {
                    store.save(configuration: configuration)
                    if configuration.isConfigured {
                        Task {
                            await feedback.flushPending()
                            _ = await topics.syncPending()
                            store.refreshMetrics(editions: editions, feedback: feedback)
                        }
                    }
                }
                .disabled(!store.canSave)
                Button {
                    Task {
                        await store.test(
                            configuration: configuration,
                            api: api,
                            feedback: feedback,
                            topics: topics
                        )
                        store.refreshMetrics(editions: editions, feedback: feedback)
                    }
                } label: {
                    HStack {
                        Label("Test connection", systemImage: "network")
                        Spacer()
                        if store.connectionStatus == .testing {
                            ProgressView()
                        } else if store.connectionStatus == .connected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if store.connectionStatus == .failed {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .disabled(store.connectionStatus == .testing || !store.canSave)
            } header: {
                Text("Private VPS")
            } footer: {
                Text(
                    "Use HTTPS or a private Tailscale address. "
                        + "The secret is stored only in this device’s Keychain."
                )
            }

            if let message = store.saveMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(VerseTheme.secondaryInk)
                }
            }

            Section("Offline reading") {
                LabeledContent("Downloaded editions", value: "\(store.cachedEditionCount)")
                LabeledContent(
                    "Last edition refresh",
                    value: store.lastRefresh?.formatted(date: .abbreviated, time: .shortened) ?? "Never"
                )
                if store.pendingMutationCount > 0 {
                    LabeledContent("Queued feedback", value: "\(store.pendingMutationCount)")
                }
                if store.failedMutationCount > 0 {
                    LabeledContent("Feedback needing retry", value: "\(store.failedMutationCount)")
                    Button("Retry feedback uploads") {
                        Task {
                            await feedback.retryFailed()
                            store.refreshMetrics(editions: editions, feedback: feedback)
                        }
                    }
                }
                Button("Clear downloaded editions", role: .destructive) {
                    store.clearEditions(editions)
                }
            }

            Section("About") {
                LabeledContent("Edition editor", value: "Nightjar")
                LabeledContent("Verse", value: "v0")
                Text("A private, finite morning reader. No account, analytics, ads, or public feed.")
                    .font(.footnote)
                    .foregroundStyle(VerseTheme.secondaryInk)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VerseTheme.paper)
        .navigationTitle("Settings")
        .task { store.refreshMetrics(editions: editions, feedback: feedback) }
    }
}
