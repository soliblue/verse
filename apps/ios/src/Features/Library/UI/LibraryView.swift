import SwiftUI

struct LibraryView: View {
    let editions: EditionRepository
    let feedback: FeedbackRepository
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
                                .foregroundStyle(VerseTheme.secondaryInk)
                        } else {
                            ForEach(store.savedStories) { story in
                                NavigationLink(value: story) {
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
                            .foregroundStyle(VerseTheme.secondaryInk)
                        } else {
                            ForEach(store.previousEditions) { edition in
                                NavigationLink(value: edition) {
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
        .background(VerseTheme.paper)
        .navigationTitle("Library")
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 64)
        }
        .onAppear { store.reloadLocal(editions: editions, feedback: feedback) }
        .task { await store.load(editions: editions, feedback: feedback) }
    }
}
