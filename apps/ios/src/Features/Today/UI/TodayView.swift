import SwiftUI

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    let editions: EditionRepository
    let feedback: FeedbackRepository
    let topics: TopicsRepository
    let configuration: ServerConfiguration
    @State private var store = TodayStore()
    @State private var focusedStoryID: StoryItem.ID?

    var body: some View {
        Group {
            if let edition = store.edition {
                let stories = edition.items.sorted { $0.position < $1.position }

                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                            NavigationLink(value: story) {
                                StoryPageView(
                                    story: story,
                                    number: index + 1,
                                    total: stories.count
                                )
                            }
                            .buttonStyle(.plain)
                            .id(story.id)
                            .containerRelativeFrame(.vertical)
                            .accessibilityIdentifier("reader-story-\(story.id)")
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $focusedStoryID)
                .accessibilityIdentifier("verse-reader")
                .onChange(of: stories.map(\.id), initial: true) { _, storyIDs in
                    if focusedStoryID.map(storyIDs.contains) != true {
                        focusedStoryID = storyIDs.first
                    }
                }
                .overlay(alignment: .top) {
                    ReaderToolbar(
                        statusMessage: store.statusMessage,
                        isRefreshing: store.isRefreshing
                    ) {
                        Task { await refresh() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            } else if store.isLoading {
                ProgressView("Preparing your edition")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Edition unavailable",
                    systemImage: "newspaper",
                    description: Text(store.statusMessage ?? "Try reopening Verse.")
                )
            }
        }
        .background(VerseTheme.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.load(
                editions: editions,
                feedback: feedback,
                topics: topics,
                configuration: configuration
            )
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, store.hasLoaded, configuration.isConfigured {
                Task { await refresh() }
            }
        }
    }

    private func refresh() async {
        await store.refresh(
            editions: editions,
            feedback: feedback,
            topics: topics,
            configuration: configuration
        )
    }
}
