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
    @State private var selectedTab = AppTab.articles
    @State private var articlesPath = NavigationPath()
    @State private var calendarPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $articlesPath) {
                TodayView(
                    editions: editions,
                    api: api,
                    feedback: feedback,
                    topics: topics,
                    explore: explore,
                    configuration: configuration
                )
                .navigationDestination(for: StoryItem.self) { story in
                    storyDetail(story)
                }
                .navigationDestination(for: EventItem.self) { event in
                    eventDetail(event)
                }
            }
            .tabItem { tabIcon(.articles) }
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
            }
            .tabItem { tabIcon(.calendar) }
            .tag(AppTab.calendar)
        }
        .background(KeyboardDismissalHost())
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackground(VerseTheme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tint(VerseTheme.accent)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .task {
            await eventFeedback.flushPending()
            await venueFeedback.flushPending()
        }
    }

    @ViewBuilder
    private func tabIcon(_ tab: AppTab) -> some View {
        Label(tab.title, systemImage: tab.systemImage)
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("app-tab-\(tab.title)")
    }

    private func storyDetail(_ story: StoryItem) -> some View {
        StoryDetailView(
            story: story,
            api: api,
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
}
