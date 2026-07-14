import SwiftUI

struct RootTabView: View {
    let configuration: ServerConfiguration
    let api: APIClient
    let editions: EditionRepository
    let feedback: FeedbackRepository
    let topics: TopicsRepository
    @Binding var appTheme: AppTheme
    @State private var selectedTab = AppTab.today
    @State private var todayPath = NavigationPath()
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
                    selectedTab: $selectedTab
                )
                .navigationDestination(for: StoryItem.self) { story in
                    StoryDetailView(story: story, feedback: feedback)
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { Label("Today", systemImage: "square.stack.3d.up") }
            .tag(AppTab.today)

            NavigationStack(path: $libraryPath) {
                LibraryView(editions: editions, feedback: feedback)
                    .navigationDestination(for: StoryItem.self) { story in
                        StoryDetailView(story: story, feedback: feedback)
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
    }
}
