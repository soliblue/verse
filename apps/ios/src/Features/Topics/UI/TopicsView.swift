import SwiftUI

struct TopicsView: View {
    let repository: TopicsRepository
    @State private var store = TopicsStore()
    @State private var editor: TopicEditorDraft?

    var body: some View {
        Group {
            if store.isLoading && store.topics.isEmpty {
                ProgressView("Loading topics")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.topics.isEmpty {
                ContentUnavailableView(
                    "No topics",
                    systemImage: "scope",
                    description: Text("Add an interest to guide Nightjar’s next edition.")
                )
            } else {
                List {
                    if let message = store.statusMessage {
                        StatusBanner(message: message, systemImage: "arrow.triangle.2.circlepath")
                            .listRowBackground(VerseTheme.paper)
                    }
                    Section {
                        ForEach(store.topics) { topic in
                            TopicRow(
                                topic: topic,
                                isDisabled: store.isBusy,
                                onToggle: {
                                    Task { await store.toggle(topic.id, repository: repository) }
                                },
                                onEdit: {
                                    editor = TopicEditorDraft(topic: topic)
                                }
                            )
                        }
                        .onDelete { offsets in
                            Task { await store.delete(at: offsets, repository: repository) }
                        }
                        .onMove { offsets, destination in
                            Task {
                                await store.move(
                                    from: offsets,
                                    to: destination,
                                    repository: repository
                                )
                            }
                        }
                    } footer: {
                        Text("Enabled topics guide ranking. Exclusions tell Nightjar what to leave out.")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await store.load(repository: repository) }
            }
        }
        .background(VerseTheme.paper)
        .navigationTitle("Topics")
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 64)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                    .disabled(store.isBusy)
                Button {
                    editor = TopicEditorDraft()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(store.isBusy)
                .accessibilityLabel("Add topic")
            }
        }
        .sheet(item: $editor) { draft in
            TopicEditorSheet(draft: draft) { saved in
                Task { await store.upsert(saved, repository: repository) }
            }
        }
        .task { await store.load(repository: repository) }
    }
}
