import SwiftUI

struct EditionView: View {
    let summary: EditionSummary
    let editions: EditionRepository
    let configuration: ServerConfiguration
    @State private var store = EditionStore()

    var body: some View {
        Group {
            if let edition = store.edition {
                List {
                    Section {
                        Text(edition.dek)
                            .font(.subheadline)
                            .foregroundStyle(VerseTheme.secondaryInk)
                            .listRowBackground(VerseTheme.paper)
                    }
                    ForEach(edition.items.sorted { $0.position < $1.position }) { story in
                        NavigationLink(value: story) {
                            StoryRowView(story: story)
                        }
                        .listRowBackground(VerseTheme.paper)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else if store.isLoading {
                ProgressView("Opening edition")
            } else {
                ContentUnavailableView {
                    Label("Edition unavailable", systemImage: "newspaper")
                } description: {
                    Text("Reconnect to the VPS and try again.")
                } actions: {
                    Button("Try again") {
                        Task {
                            await store.load(
                                id: summary.id,
                                repository: editions,
                                configuration: configuration
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .background(VerseTheme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load(id: summary.id, repository: editions, configuration: configuration)
        }
    }
}
