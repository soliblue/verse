import SwiftUI

struct DeepDiveSection: View {
    let state: CachedStoryState?
    let isDisabled: Bool
    let onRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nightjar deep dive", systemImage: "moon.stars")
                .font(.utility(12))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(VerseTheme.ink)
            switch state?.deepDiveStatus ?? .notRequested {
            case .notRequested:
                Text("Queue a deeper, source-backed briefing for the next overnight run.")
                    .font(.reading(15))
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
                        .font(.display(20))
                        .foregroundStyle(VerseTheme.ink)
                }
                if let body = state?.deepDiveBody {
                    Text(body)
                        .font(.reading(16))
                        .foregroundStyle(VerseTheme.ink)
                        .textSelection(.enabled)
                }
                ForEach(state?.citations ?? []) { citation in
                    CitationRow(citation: citation)
                }
            }
        }
        .padding(16)
        .background(VerseTheme.surface)
        .overlay {
            Rectangle()
                .stroke(VerseTheme.border, lineWidth: 1)
        }
    }

    private func requestButton(_ title: String) -> some View {
        Button(title, systemImage: "moon.stars") {
            onRequest()
        }
        .buttonStyle(.borderedProminent)
        .tint(VerseTheme.ink)
        .disabled(isDisabled)
    }
}
