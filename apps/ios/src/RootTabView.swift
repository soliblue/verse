import SwiftUI

struct RootTabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    private var showsFloatingTabs: Bool {
        switch selectedTab {
        case .today: todayPath.isEmpty
        case .library: libraryPath.isEmpty
        case .topics: topicsPath.isEmpty
        case .settings: settingsPath.isEmpty
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack(path: $todayPath) {
                    TodayView(
                        editions: editions,
                        feedback: feedback,
                        topics: topics,
                        configuration: configuration
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
                }
                .toolbar(.hidden, for: .tabBar)
                .tabItem { Label("Library", systemImage: "bookmark") }
                .tag(AppTab.library)

                NavigationStack(path: $topicsPath) {
                    TopicsView(repository: topics)
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
                        topics: topics
                    )
                }
                .toolbar(.hidden, for: .tabBar)
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(AppTab.settings)
            }

            if showsFloatingTabs {
                FloatingTabBar(selection: $selectedTab)
                    .padding(.bottom, 8)
                    .transition(
                        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
                    )
            }
        }
        .tint(VerseTheme.accent)
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: showsFloatingTabs)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
