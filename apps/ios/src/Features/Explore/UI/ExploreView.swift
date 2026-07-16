import SwiftUI

struct ExploreView: View {
    let repository: ExploreRepository
    let feedback: EventFeedbackRepository
    let calendar: CalendarRepository
    let configuration: ServerConfiguration
    @State private var store = ExploreStore()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Explore view", selection: $store.mode) {
                ForEach(ExploreMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .accessibilityIdentifier("explore-mode")

            if let payload = store.payload {
                switch store.mode {
                case .list:
                    ExploreListView(sections: store.sections, calendar: calendar)
                case .calendar:
                    ExploreCalendarView(payload: payload, calendarRepository: calendar)
                case .places:
                    ExplorePlacesView(payload: payload)
                }
            } else if store.isLoading {
                ProgressView("Finding Berlin")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Explore unavailable",
                    systemImage: "sparkles",
                    description: Text(store.statusMessage ?? "Try again later.")
                )
            }
        }
        .background(VerseTheme.paper)
        .navigationTitle("Explore")
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
