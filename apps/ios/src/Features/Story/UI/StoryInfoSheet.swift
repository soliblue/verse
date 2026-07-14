import SwiftUI

struct StoryInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let story: StoryItem
    let state: CachedStoryState?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Summary")
                            .font(.utility(12))
                            .tracking(0.9)
                            .textCase(.uppercase)
                        Text(story.summary)
                            .font(.reading(17))
                            .foregroundStyle(VerseTheme.secondaryInk)
                            .lineSpacing(4)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why it was selected")
                            .font(.utility(12))
                            .tracking(0.9)
                            .textCase(.uppercase)
                        Text(story.whySelected)
                            .font(.reading(17))
                            .foregroundStyle(VerseTheme.secondaryInk)
                            .lineSpacing(4)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sources")
                            .font(.utility(12))
                            .tracking(0.9)
                            .textCase(.uppercase)
                        Text(
                            "\(story.sourceName) · \(DateFormatting.shortDate(story.publishedAt))"
                                + " · \(story.readingMinutes) min"
                        )
                        .font(.utility(12))
                        .foregroundStyle(VerseTheme.secondaryInk)
                        Link(destination: story.sourceURL) {
                            Label("Open original", systemImage: "arrow.up.right")
                        }
                        .accessibilityIdentifier("story-original")
                        ForEach(story.citations) { citation in
                            CitationRow(citation: citation)
                        }
                    }

                    switch state?.deepDiveStatus ?? .notRequested {
                    case .notRequested:
                        EmptyView()
                    case .queued:
                        Label("Deep dive queued for the next edition.", systemImage: "clock")
                            .font(.reading(16))
                    case .failed:
                        Label("The latest deep dive attempt failed.", systemImage: "exclamationmark.triangle")
                            .font(.reading(16))
                    case .ready:
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Deep dive")
                                .font(.utility(12))
                                .tracking(0.9)
                                .textCase(.uppercase)
                            if let title = state?.deepDiveTitle {
                                Text(title)
                                    .font(.display(24))
                            }
                            if let body = state?.deepDiveBody {
                                Text(body)
                                    .font(.reading(17))
                                    .lineSpacing(4)
                                    .textSelection(.enabled)
                            }
                            ForEach(state?.citations ?? []) { citation in
                                CitationRow(citation: citation)
                            }
                        }
                    }
                }
                .foregroundStyle(VerseTheme.ink)
                .padding(24)
            }
            .background(VerseTheme.paper)
            .navigationTitle("Story details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
