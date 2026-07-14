import SwiftUI

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    let editions: EditionRepository
    let feedback: FeedbackRepository
    let topics: TopicsRepository
    let configuration: ServerConfiguration
    @State private var store = TodayStore()

    var body: some View {
        Group {
            if let edition = store.edition {
                List {
                    EditionHeaderView(edition: edition)
                        .listRowSeparator(.hidden)
                        .listRowBackground(VerseTheme.paper)
                    if let message = store.statusMessage {
                        StatusBanner(message: message, systemImage: "wifi.slash")
                            .listRowSeparator(.hidden)
                            .listRowBackground(VerseTheme.paper)
                    }
                    ForEach(edition.items.sorted { $0.position < $1.position }) { story in
                        NavigationLink {
                            StoryDetailView(story: story, feedback: feedback)
                        } label: {
                            StoryRowView(story: story)
                        }
                        .listRowBackground(VerseTheme.paper)
                    }
                    Text("You reached the end of today’s edition.")
                        .font(.footnote)
                        .foregroundStyle(VerseTheme.secondaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowSeparator(.hidden)
                        .listRowBackground(VerseTheme.paper)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await store.refresh(
                        editions: editions,
                        feedback: feedback,
                        topics: topics,
                        configuration: configuration
                    )
                }
            } else if store.isLoading {
                ProgressView("Preparing your edition")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Edition unavailable",
                    systemImage: "newspaper",
                    description: Text(store.statusMessage ?? "Try reopening Verse.")
                )
            }
        }
        .background(VerseTheme.paper)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await store.refresh(
                            editions: editions,
                            feedback: feedback,
                            topics: topics,
                            configuration: configuration
                        )
                    }
                } label: {
                    if store.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(store.isRefreshing)
                .accessibilityLabel("Refresh edition")
            }
        }
        .task {
            await store.load(
                editions: editions,
                feedback: feedback,
                topics: topics,
                configuration: configuration
            )
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, store.hasLoaded, configuration.isConfigured {
                Task {
                    await store.refresh(
                        editions: editions,
                        feedback: feedback,
                        topics: topics,
                        configuration: configuration
                    )
                }
            }
        }
    }
}
