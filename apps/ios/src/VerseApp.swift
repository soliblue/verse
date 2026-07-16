import SwiftData
import SwiftUI

@main
@MainActor
struct VerseApp: App {
    private let container: ModelContainer
    @State private var configuration: ServerConfiguration
    @State private var appTheme: AppTheme
    private let api: APIClient
    private let editions: EditionRepository
    private let feedback: FeedbackRepository
    private let topics: TopicsRepository
    private let explore: ExploreRepository
    private let eventFeedback: EventFeedbackRepository
    private let venueFeedback: VenueFeedbackRepository
    private let calendar: CalendarRepository
    private let covers: CoverRepository

    init() {
        FontRegistrar.registerBundledFonts()
        let container = try! ModelContainer(
            for: CachedEdition.self,
            CachedEditionIndex.self,
            CachedTopics.self,
            CachedStoryState.self,
            PendingMutation.self,
            CachedExplore.self,
            CachedEventFeedbackState.self,
            CachedCalendarLink.self,
            CachedCoverAsset.self
        )
        let configuration = ServerConfiguration()
        let api = APIClient(configuration: configuration)
        self.container = container
        _configuration = State(initialValue: configuration)
        _appTheme = State(initialValue: AppTheme.persisted)
        self.api = api
        editions = EditionRepository(context: container.mainContext, api: api)
        feedback = FeedbackRepository(context: container.mainContext, api: api)
        topics = TopicsRepository(context: container.mainContext, api: api)
        explore = ExploreRepository(context: container.mainContext, api: api)
        eventFeedback = EventFeedbackRepository(context: container.mainContext, api: api)
        venueFeedback = VenueFeedbackRepository(context: container.mainContext, api: api)
        calendar = CalendarRepository(context: container.mainContext)
        covers = CoverRepository(context: container.mainContext, api: api)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(
                configuration: configuration,
                api: api,
                editions: editions,
                feedback: feedback,
                topics: topics,
                explore: explore,
                eventFeedback: eventFeedback,
                venueFeedback: venueFeedback,
                calendar: calendar,
                covers: covers,
                appTheme: $appTheme
            )
            .preferredColorScheme(appTheme.colorScheme)
            .environment(\.locale, Locale(identifier: "en"))
        }
        .modelContainer(container)
    }
}
