import SwiftUI

struct StoryDetailView: View {
    let story: StoryItem
    let feedback: FeedbackRepository
    @State private var store = StoryDetailStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let imageURL = story.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(VerseTheme.surface)
                            .overlay { ProgressView() }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(story.kind.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.9)
                        .foregroundStyle(VerseTheme.amber)
                    Text(story.title)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(VerseTheme.ink)
                    Text(story.summary)
                        .font(.title3)
                        .foregroundStyle(VerseTheme.secondaryInk)
                    HStack(spacing: 6) {
                        Text(story.sourceName)
                        Text("·")
                        Text(DateFormatting.shortDate(story.publishedAt))
                        Text("·")
                        Text("\(story.readingMinutes) min")
                    }
                    .font(.caption)
                    .foregroundStyle(VerseTheme.secondaryInk)
                }
                Divider()
                Text(story.body)
                    .font(.body)
                    .foregroundStyle(VerseTheme.ink)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Why this made Verse")
                        .font(.headline)
                    Text(story.whySelected)
                        .font(.subheadline)
                        .foregroundStyle(VerseTheme.secondaryInk)
                }
                .padding(16)
                .background(VerseTheme.amber.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sources")
                        .font(.headline)
                    Link(destination: story.sourceURL) {
                        Label("Read the original at \(story.sourceName)", systemImage: "safari")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(story.citations) { citation in
                        CitationRow(citation: citation)
                    }
                }
                FeedbackBar(preference: store.preference, isDisabled: store.isSending) { preference in
                    Task {
                        await store.setPreference(preference, story: story, repository: feedback)
                    }
                }
                DeepDiveSection(state: store.state, isDisabled: store.isSending) {
                    Task { await store.requestDeepDive(story: story, repository: feedback) }
                }
            }
            .padding(16)
        }
        .background(VerseTheme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await store.toggleSaved(story: story, repository: feedback) }
                } label: {
                    Image(systemName: store.isSaved ? "bookmark.fill" : "bookmark")
                }
                .disabled(store.isSending)
                .accessibilityLabel(store.isSaved ? "Remove bookmark" : "Save story")
                ShareLink(item: story.sourceURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share original story")
            }
        }
        .task { await store.load(story: story, repository: feedback) }
    }
}
