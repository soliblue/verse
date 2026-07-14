import SwiftUI

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    let editions: EditionRepository
    let feedback: FeedbackRepository
    let topics: TopicsRepository
    let configuration: ServerConfiguration
    @Binding var selectedTab: AppTab
    @State private var store = TodayStore()
    @State private var focusedStoryID: StoryItem.ID?

    var body: some View {
        Group {
            if let edition = store.edition {
                let stories = edition.items.sorted { $0.position < $1.position }

                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                            TodayStoryPage(
                                story: story,
                                number: index + 1,
                                total: stories.count,
                                feedback: feedback
                            )
                            .id(story.id)
                            .containerRelativeFrame(.vertical)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $focusedStoryID)
                .refreshable { await refresh() }
                .accessibilityIdentifier("verse-reader")
                .overlay(alignment: .bottom) {
                    if let message = store.statusMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(VerseTheme.secondaryInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                            .accessibilityIdentifier("reader-status")
                    }
                }
                .onChange(of: stories.map(\.id), initial: true) { _, storyIDs in
                    if focusedStoryID.map(storyIDs.contains) != true {
                        focusedStoryID = storyIDs.first
                    }
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
        .overlay(alignment: .topLeading) {
            AppNavigationMenu(selection: $selectedTab)
                .padding(.leading, 12)
                .padding(.top, 4)
        }
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
