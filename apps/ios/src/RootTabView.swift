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
    @Binding var appTheme: AppTheme
    @State private var selectedTab = AppTab.articles
    @State private var articlesPath = NavigationPath()
    @State private var calendarPath = NavigationPath()
    @State private var placesPath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    @State private var topicsPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $articlesPath) {
                TodayView(
                    editions: editions,
                    feedback: feedback,
                    topics: topics,
                    configuration: configuration,
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
            .tabItem { Label("Articles", systemImage: "doc.text.image") }
            .tag(AppTab.articles)

            NavigationStack(path: $calendarPath) {
                ExploreView(
                    mode: .calendar,
                    repository: explore,
                    feedback: eventFeedback,
                    configuration: configuration
                )
                .navigationDestination(for: EventItem.self) { event in
                    eventDetail(event)
                }
                .navigationDestination(for: Venue.self) { venue in
                    venueDetail(venue)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        AppNavigationMenu(selection: $selectedTab)
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Calendar", systemImage: "calendar") }
            .tag(AppTab.calendar)

            NavigationStack(path: $placesPath) {
                ExploreView(
                    mode: .places,
                    repository: explore,
                    feedback: eventFeedback,
                    configuration: configuration
                )
                .navigationDestination(for: EventItem.self) { event in
                    eventDetail(event)
                }
                .navigationDestination(for: Venue.self) { venue in
                    venueDetail(venue)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        AppNavigationMenu(selection: $selectedTab)
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Places", systemImage: "mappin.and.ellipse") }
            .tag(AppTab.places)

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
        .background(KeyboardDismissalHost())
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(VerseTheme.accent)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onChange(of: selectedTab) { _, tab in
            resetPath(for: tab)
        }
        .task {
            await eventFeedback.flushPending()
            await venueFeedback.flushPending()
        }
    }

    private func storyDetail(_ story: StoryItem) -> some View {
        StoryDetailView(
            story: story,
            feedback: feedback,
            explore: explore
        )
    }

    private func eventDetail(_ event: EventItem) -> some View {
        EventDetailView(
            event: event,
            feedback: eventFeedback,
            calendar: calendar
        )
    }

    private func venueDetail(_ venue: Venue) -> some View {
        VenueDetailView(
            venue: venue,
            feedback: venueFeedback
        )
    }

    private func resetPath(for tab: AppTab) {
        switch tab {
        case .articles: articlesPath = NavigationPath()
        case .calendar: calendarPath = NavigationPath()
        case .places: placesPath = NavigationPath()
        case .library: libraryPath = NavigationPath()
        case .topics: topicsPath = NavigationPath()
        case .settings: settingsPath = NavigationPath()
        }
    }
}
