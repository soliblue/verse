import SwiftUI

struct RootTabView: View {
    let configuration: ServerConfiguration
    let api: APIClient
    let editions: EditionRepository
    let feedback: FeedbackRepository
    let topics: TopicsRepository
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
                    configuration: configuration
                )
            }
            .tabItem { Label("Today", systemImage: "sun.horizon") }
            .tag(AppTab.today)

            NavigationStack(path: $libraryPath) {
                LibraryView(editions: editions, feedback: feedback, configuration: configuration)
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
            .tag(AppTab.library)

            NavigationStack(path: $topicsPath) {
                TopicsView(repository: topics)
            }
            .tabItem { Label("Topics", systemImage: "scope") }
            .tag(AppTab.topics)

            NavigationStack(path: $settingsPath) {
                SettingsView(
                    configuration: configuration,
                    api: api,
                    editions: editions,
                    feedback: feedback,
                    topics: topics
                )
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .tint(VerseTheme.blue)
    }
}
