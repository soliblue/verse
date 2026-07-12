import SwiftUI

struct EditionView: View {
    let summary: EditionSummary
    let editions: EditionRepository
    let feedback: FeedbackRepository
    let configuration: ServerConfiguration
    @State private var store = EditionStore()

    var body: some View {
        Group {
            if let edition = store.edition {
                List {
                    Section {
                        Text(edition.dek)
                            .font(.subheadline)
                            .foregroundStyle(MorrowTheme.secondaryInk)
                            .listRowBackground(MorrowTheme.paper)
                    }
                    ForEach(edition.items.sorted { $0.position < $1.position }) { story in
                        NavigationLink {
                            StoryDetailView(story: story, feedback: feedback)
                        } label: {
                            StoryRowView(story: story)
                        }
                        .listRowBackground(MorrowTheme.paper)
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
        .background(MorrowTheme.paper)
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load(id: summary.id, repository: editions, configuration: configuration)
        }
    }
}
