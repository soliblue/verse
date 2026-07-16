import SwiftUI

struct RootTabView: View {
    let configuration: ServerConfiguration
    let api: APIClient
    let editions: EditionRepository
    let feedback: FeedbackRepository
    let topics: TopicsRepository
    let explore: ExploreRepository
    let eventFeedback: EventFeedbackRepository
    let venueFeedback: VenueFeedbackRepository
    let calendar: CalendarRepository
    let covers: CoverRepository
    @Binding var appTheme: AppTheme
    @State private var selectedTab = AppTab.today
    @State private var todayPath = NavigationPath()
    @State private var explorePath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    @State private var topicsPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $todayPath) {
                TodayView(
                    editions: editions,
                    feedback: feedback,
                    topics: topics,
                    configuration: configuration,
                    covers: covers,
                    selectedTab: $selectedTab
                )
                .navigationDestination(for: StoryItem.self) { story in
                    storyDetail(story)
                }
                .navigationDestination(for: EventItem.self) { event in
                    eventDetail(event)
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Today", systemImage: "square.stack.3d.up") }
            .tag(AppTab.today)

            NavigationStack(path: $explorePath) {
                ExploreView(
                    repository: explore,
                    feedback: eventFeedback,
                    calendar: calendar,
                    configuration: configuration
                )
                .navigationDestination(for: EventItem.self) { event in
                    eventDetail(event)
                }
                .navigationDestination(for: Venue.self) { venue in
                    VenueDetailView(
                        venue: venue,
                        explore: explore,
                        feedback: venueFeedback,
                        calendar: calendar
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        AppNavigationMenu(selection: $selectedTab)
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Explore", systemImage: "sparkles") }
            .tag(AppTab.explore)

            NavigationStack(path: $libraryPath) {
                LibraryView(editions: editions, feedback: feedback)
                    .navigationDestination(for: StoryItem.self) { story in
                        storyDetail(story)
                    }
                    .navigationDestination(for: EventItem.self) { event in
                        eventDetail(event)
                    }
                    .navigationDestination(for: EditionSummary.self) { edition in
                        EditionView(
                            summary: edition,
                            editions: editions,
                            configuration: configuration
                        )
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            AppNavigationMenu(selection: $selectedTab)
                        }
                    }
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Library", systemImage: "bookmark") }
            .tag(AppTab.library)

            NavigationStack(path: $topicsPath) {
                TopicsView(repository: topics)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            AppNavigationMenu(selection: $selectedTab)
                        }
                    }
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Topics", systemImage: "scope") }
            .tag(AppTab.topics)

            NavigationStack(path: $settingsPath) {
                SettingsView(
                    configuration: configuration,
                    api: api,
                    editions: editions,
                    feedback: feedback,
                    topics: topics,
                    appTheme: $appTheme
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        AppNavigationMenu(selection: $selectedTab)
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
            .tag(AppTab.settings)
        }
        .tint(VerseTheme.accent)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .task {
            await eventFeedback.flushPending()
            await venueFeedback.flushPending()
        }
    }

    private func storyDetail(_ story: StoryItem) -> some View {
        StoryDetailView(
            story: story,
            feedback: feedback,
            explore: explore,
            eventFeedback: eventFeedback,
            calendar: calendar,
            covers: covers
        )
    }

    private func eventDetail(_ event: EventItem) -> some View {
        EventDetailView(
            event: event,
            explore: explore,
            feedback: eventFeedback,
            calendar: calendar
        )
    }
}
