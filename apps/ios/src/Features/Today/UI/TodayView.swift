import SwiftUI

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    let editions: EditionRepository
    let api: APIClient
    let feedback: FeedbackRepository
    let topics: TopicsRepository
    let explore: ExploreRepository
    let configuration: ServerConfiguration
    @State private var store = TodayStore()
    @State private var toolbarStore = StoryDetailStore()
    @State private var focusedStoryID: StoryItem.ID?
    @State private var detailStory: StoryItem?

    var body: some View {
        Group {
            if store.edition != nil {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                            StoryPageView(
                                story: story,
                                number: index + 1,
                                total: stories.count,
                                api: api,
                                relatedEvents: explore.events(ids: story.relatedEventIDs ?? [])
                            )
                            .refreshable { await refresh() }
                            .id(story.id)
                            .containerRelativeFrame(.horizontal)
                            .accessibilityIdentifier("reader-story-\(index + 1)")
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $focusedStoryID)
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
        .background(pageBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let story = focusedStory {
                StoryPageToolbar(
                    sourceURL: story.sourceURL,
                    isSaved: toolbarStore.isSaved,
                    preference: toolbarStore.preference,
                    deepDiveStatus: toolbarStore.deepDiveStatus,
                    isDisabled: toolbarStore.isSending,
                    foregroundColor: VerseTheme.ink,
                    onSave: {
                        Task {
                            await toolbarStore.toggleSaved(story: story, repository: feedback)
                        }
                    },
                    onPreference: { preference in
                        Task {
                            await toolbarStore.setPreference(
                                preference,
                                story: story,
                                repository: feedback
                            )
                        }
                    },
                    onDeepDive: {
                        Task {
                            await toolbarStore.requestDeepDive(story: story, repository: feedback)
                        }
                    },
                    onShowDetails: { detailStory = story }
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $detailStory) { story in
            StoryInfoSheet(story: story, state: toolbarStore.state)
        }
        .task(id: focusedStory?.id) {
            guard let focusedStory else { return }
            await toolbarStore.load(story: focusedStory, repository: feedback)
        }
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

    private var stories: [StoryItem] {
        store.edition?.items
            .filter { $0.kind != "event" }
            .sorted { $0.position < $1.position } ?? []
    }

    private var focusedStory: StoryItem? {
        return stories.first { $0.id == focusedStoryID } ?? stories.first
    }

    private var pageBackground: Color {
        guard let focusedStory else { return VerseTheme.paper }
        return VerseTheme.storyBackground(for: focusedStory.id)
    }
}
