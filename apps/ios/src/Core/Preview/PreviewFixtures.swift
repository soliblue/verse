#if DEBUG
import Foundation

enum PreviewFixtures {
    static let citation = Citation(
        title: "A source-backed paper",
        url: URL(string: "https://example.com/paper")!,
        sourceName: "Research Lab",
        publishedAt: "2026-07-03T00:00:00Z"
    )

    static let story = StoryItem(
        id: "preview-story",
        position: 1,
        kind: "paper",
        topicIDs: ["audiovisual-techniques"],
        title: "Where a video model begins to understand motion",
        summary:
            "A close look at when speed, acceleration, and direction become readable inside a video model.",
        body: "The stored edition contains the complete source-backed briefing.",
        whySelected: "It connects a concrete model finding to motion control for audiovisual practice.",
        sourceName: "Research Lab",
        sourceURL: URL(string: "https://example.com/paper")!,
        publishedAt: "2026-07-03T00:00:00Z",
        readingMinutes: 4,
        relatedEventIDs: nil,
        citations: [citation],
        feedback: .empty,
        deepDive: .empty
    )

    static let edition = EditionPayload(
        id: "preview-edition",
        date: "2026-07-12",
        title: "Signals, Soundscapes, and Berlin in Motion",
        dek: "A finite Sunday edition on video, sound design, and dates worth putting on the calendar.",
        generatedAt: "2026-07-12T06:00:00Z",
        items: [story]
    )
}
#endif
