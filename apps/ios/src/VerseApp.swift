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

    init() {
        FontRegistrar.registerBundledFonts()
        let container = try! ModelContainer(
            for: CachedEdition.self,
            CachedEditionIndex.self,
            CachedTopics.self,
            CachedStoryState.self,
            PendingMutation.self
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
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(
                configuration: configuration,
                api: api,
                editions: editions,
                feedback: feedback,
                topics: topics,
                appTheme: $appTheme
            )
            .preferredColorScheme(appTheme.colorScheme)
            .environment(\.locale, Locale(identifier: "en"))
        }
        .modelContainer(container)
    }
}
