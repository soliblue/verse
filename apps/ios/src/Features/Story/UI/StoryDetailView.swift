import SwiftUI

struct StoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let story: StoryItem
    let feedback: FeedbackRepository
    @State private var store = StoryDetailStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
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
                    .frame(height: 260)
                    .clipped()
                    .padding(.bottom, 24)
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Text(story.kind.replacingOccurrences(of: "_", with: " ").uppercased())
                        Text("/")
                            .foregroundStyle(VerseTheme.border)
                        Text(story.sourceName.uppercased())
                            .lineLimit(1)
                    }
                    .font(.utility(12))
                    .tracking(0.9)
                    .foregroundStyle(VerseTheme.secondaryInk)
                    Text(story.title)
                        .font(.display(36))
                        .foregroundStyle(VerseTheme.ink)
                        .accessibilityIdentifier("story-detail")
                    Text(story.summary)
                        .font(.reading(19))
                        .lineSpacing(4)
                        .foregroundStyle(VerseTheme.secondaryInk)
                    HStack(spacing: 6) {
                        Text(DateFormatting.shortDate(story.publishedAt))
                        Text("·")
                        Text("\(story.readingMinutes) min")
                    }
                    .font(.utility(12))
                    .foregroundStyle(VerseTheme.secondaryInk)
                }
                .padding(.bottom, 28)
                Rectangle()
                    .fill(VerseTheme.border)
                    .frame(height: 1)
                    .padding(.bottom, 28)
                Text(story.body)
                    .font(.reading(17))
                    .foregroundStyle(VerseTheme.ink)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .padding(.bottom, 32)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Why this made Verse")
                        .font(.utility(12))
                        .tracking(0.9)
                        .textCase(.uppercase)
                    Text(story.whySelected)
                        .font(.reading(16))
                        .lineSpacing(3)
                        .foregroundStyle(VerseTheme.secondaryInk)
                }
                .padding(.leading, 16)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(VerseTheme.accent)
                        .frame(width: 3)
                }
                .padding(.bottom, 36)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sources")
                        .font(.utility(12))
                        .tracking(0.9)
                        .textCase(.uppercase)
                    Link(destination: story.sourceURL) {
                        Label("Read the original at \(story.sourceName)", systemImage: "safari")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(story.citations) { citation in
                        CitationRow(citation: citation)
                    }
                }
                .padding(.bottom, 36)
                FeedbackBar(preference: store.preference, isDisabled: store.isSending) { preference in
                    Task {
                        await store.setPreference(preference, story: story, repository: feedback)
                    }
                }
                .padding(.bottom, 28)
                DeepDiveSection(state: store.state, isDisabled: store.isSending) {
                    Task { await store.requestDeepDive(story: story, repository: feedback) }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 76)
            .padding(.bottom, 48)
        }
        .background(VerseTheme.paper)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            StoryToolbar(
                sourceURL: story.sourceURL,
                isSaved: store.isSaved,
                isDisabled: store.isSending,
                onBack: { dismiss() },
                onSave: {
                    Task { await store.toggleSaved(story: story, repository: feedback) }
                }
            )
        }
        .task { await store.load(story: story, repository: feedback) }
    }
}
