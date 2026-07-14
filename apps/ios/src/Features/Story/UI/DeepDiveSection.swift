import SwiftUI

struct DeepDiveSection: View {
    let state: CachedStoryState?
    let isDisabled: Bool
    let onRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nightjar deep dive", systemImage: "moon.stars")
                .font(.headline)
                .foregroundStyle(VerseTheme.ink)
            switch state?.deepDiveStatus ?? .notRequested {
            case .notRequested:
                Text("Queue a deeper, source-backed briefing for the next overnight run.")
                    .font(.subheadline)
                    .foregroundStyle(VerseTheme.secondaryInk)
                requestButton("Request deep dive")
            case .queued:
                StatusBanner(
                    message: "Queued for the next Nightjar run.",
                    systemImage: "clock.badge.checkmark"
                )
            case .failed:
                StatusBanner(
                    message: "The last deep-dive attempt failed. The story is still safe.",
                    systemImage: "exclamationmark.triangle"
                )
                requestButton("Try again")
            case .ready:
                if let title = state?.deepDiveTitle {
                    Text(title)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(VerseTheme.ink)
                }
                if let body = state?.deepDiveBody {
                    Text(body)
                        .font(.body)
                        .foregroundStyle(VerseTheme.ink)
                        .textSelection(.enabled)
                }
                ForEach(state?.citations ?? []) { citation in
                    CitationRow(citation: citation)
                }
            }
        }
        .padding(16)
        .background(VerseTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func requestButton(_ title: String) -> some View {
        Button(title, systemImage: "moon.stars") {
            onRequest()
        }
        .buttonStyle(.borderedProminent)
        .tint(VerseTheme.blue)
        .disabled(isDisabled)
    }
}
