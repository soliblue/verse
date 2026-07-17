import SwiftUI

struct ExploreView: View {
    let mode: ExploreMode
    let repository: ExploreRepository
    let feedback: EventFeedbackRepository
    let configuration: ServerConfiguration
    @State private var store = ExploreStore()

    var body: some View {
        Group {
            if let payload = store.payload {
                switch mode {
                case .calendar:
                    ExploreCalendarView(payload: payload)
                case .places:
                    ExplorePlacesView(payload: payload)
                }
            } else if store.isLoading {
                ProgressView("Loading \(mode.rawValue.lowercased())")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "\(mode.rawValue) unavailable",
                    systemImage: mode.systemImage,
                    description: Text(store.statusMessage ?? "Try again later.")
                )
            }
        }
        .background(VerseTheme.paper)
        .accessibilityIdentifier(mode.accessibilityIdentifier)
        .refreshable { await store.refresh(repository: repository) }
        .onAppear {
            if store.payload != nil, configuration.isConfigured {
                Task { await store.refresh(repository: repository) }
            }
        }
        .task {
            await feedback.flushPending()
            await store.load(repository: repository, configuration: configuration)
        }
    }
}
