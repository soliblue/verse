import SwiftUI

struct SettingsView: View {
    let configuration: ServerConfiguration
    let api: APIClient
    let feedback: FeedbackRepository
    let topics: TopicsRepository
    @State private var store: SettingsStore
    @State private var nightjar = NightjarRunStore()
    @State private var prompt: SettingsPrompt?
    @State private var revealSecret = false

    init(
        configuration: ServerConfiguration,
        api: APIClient,
        feedback: FeedbackRepository,
        topics: TopicsRepository
    ) {
        self.configuration = configuration
        self.api = api
        self.feedback = feedback
        self.topics = topics
        _store = State(initialValue: SettingsStore(configuration: configuration))
    }

    var body: some View {
        Form {
            Section("Private VPS") {
                TextField("https://verse.example.com", text: $store.serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Server URL")
                HStack {
                    Group {
                        if revealSecret {
                            TextField("Device secret", text: $store.deviceSecret)
                        } else {
                            SecureField("Device secret", text: $store.deviceSecret)
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
                Button("Save connection") {
                    store.save(configuration: configuration)
                    if configuration.isConfigured {
                        Task {
                            await feedback.flushPending()
                            _ = await topics.syncPending()
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
                    }
                } label: {
                    HStack {
                        Text("Test connection")
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
                if let message = store.saveMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(VerseTheme.secondaryInk)
                }
            }

            Section("Prompts") {
                ForEach(SettingsPrompt.allCases) { item in
                    Button {
                        prompt = item
                    } label: {
                        HStack {
                            Text(item.title)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Section("Nightjar") {
                ForEach(NightjarJob.allCases) { job in
                    Button("Run \(job.title)") {
                        Task { await nightjar.run(job, api: api) }
                    }
                    .disabled(nightjar.running != nil || !configuration.isConfigured)
                }
                if let message = nightjar.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(VerseTheme.secondaryInk)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .background(VerseTheme.paper)
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("settings-screen")
        .sheet(item: $prompt) { item in
            switch item {
            case .topics:
                TopicsEditorView(repository: topics)
            case .articles:
                NightjarEditorView(job: .articles, api: api)
            case .events:
                NightjarEditorView(job: .events, api: api)
            }
        }
    }
}
