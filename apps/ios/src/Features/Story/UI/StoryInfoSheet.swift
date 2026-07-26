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
                            .font(.caption)
                            .tracking(0.9)
                            .textCase(.uppercase)
                        Text(story.summary)
                            .font(.body)
                            .foregroundStyle(VerseTheme.secondaryInk)
                            .lineSpacing(4)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why it was selected")
                            .font(.caption)
                            .tracking(0.9)
                            .textCase(.uppercase)
                        Text(story.whySelected)
                            .font(.body)
                            .foregroundStyle(VerseTheme.secondaryInk)
                            .lineSpacing(4)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sources")
                            .font(.caption)
                            .tracking(0.9)
                            .textCase(.uppercase)
                        Text(
                            "\(story.sourceName) · \(DateFormatting.shortDate(story.publishedAt))"
                                + " · \(story.readingMinutes) min"
                        )
                        .font(.caption)
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
                            .font(.body)
                    case .failed:
                        Label("The latest deep dive attempt failed.", systemImage: "exclamationmark.triangle")
                            .font(.body)
                    case .ready:
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Deep dive")
                                .font(.caption)
                                .tracking(0.9)
                                .textCase(.uppercase)
                            if let title = state?.deepDiveTitle {
                                Text(title)
                                    .font(.title3)
                            }
                            if let body = state?.deepDiveBody {
                                Text(body)
                                    .font(.body)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .accessibilityIdentifier("story-info")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
