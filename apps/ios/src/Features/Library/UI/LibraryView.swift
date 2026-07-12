import SwiftUI

struct LibraryView: View {
    let editions: EditionRepository
    let feedback: FeedbackRepository
    let configuration: ServerConfiguration
    @State private var store = LibraryStore()

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Opening library")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Saved") {
                        if store.savedStories.isEmpty {
                            Label("Stories you bookmark appear here.", systemImage: "bookmark")
                                .font(.subheadline)
                                .foregroundStyle(MorrowTheme.secondaryInk)
                        } else {
                            ForEach(store.savedStories) { story in
                                NavigationLink {
                                    StoryDetailView(story: story, feedback: feedback)
                                } label: {
                                    StoryRowView(story: story, isSaved: true)
                                }
                            }
                        }
                    }
                    Section("Previous editions") {
                        if store.previousEditions.isEmpty {
                            Label(
                                "Past editions appear after the next Nightjar run.",
                                systemImage: "clock.arrow.circlepath"
                            )
                            .font(.subheadline)
                            .foregroundStyle(MorrowTheme.secondaryInk)
                        } else {
                            ForEach(store.previousEditions) { edition in
                                NavigationLink {
                                    EditionView(
                                        summary: edition,
                                        editions: editions,
                                        feedback: feedback,
                                        configuration: configuration
                                    )
                                } label: {
                                    EditionSummaryRow(edition: edition)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .refreshable { await store.refresh(editions: editions, feedback: feedback) }
            }
        }
        .background(MorrowTheme.paper)
        .navigationTitle("Library")
        .onAppear { store.reloadLocal(editions: editions, feedback: feedback) }
        .task { await store.load(editions: editions, feedback: feedback) }
    }
}
