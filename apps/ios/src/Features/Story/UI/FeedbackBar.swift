import SwiftUI

struct FeedbackBar: View {
    let preference: FeedbackPreference?
    let isDisabled: Bool
    let onSelect: (FeedbackPreference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shape tomorrow")
                .font(.utility(12))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(VerseTheme.ink)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    feedbackButton("More like this", icon: "hand.thumbsup", value: .moreLikeThis)
                    feedbackButton("Less", icon: "hand.thumbsdown", value: .lessLikeThis)
                }
                feedbackButton("Too basic", icon: "textformat.size.smaller", value: .tooBasic)
                    .gridCellColumns(2)
            }
        }
    }

    private func feedbackButton(
        _ title: String,
        icon: String,
        value: FeedbackPreference
    ) -> some View {
        Button {
            onSelect(value)
        } label: {
            Label(title, systemImage: preference == value ? "checkmark" : icon)
                .font(.utility(11))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    preference == value ? VerseTheme.ink : VerseTheme.surface,
                    in: Capsule()
                )
                .foregroundStyle(preference == value ? VerseTheme.paper : VerseTheme.ink)
                .overlay {
                    Capsule()
                        .stroke(VerseTheme.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityValue(preference == value ? "Selected" : "")
    }
}

#if DEBUG
#Preview("Feedback") {
    VStack(spacing: 24) {
        FeedbackBar(preference: nil, isDisabled: false) { _ in }
        FeedbackBar(preference: .moreLikeThis, isDisabled: false) { _ in }
    }
    .padding()
    .background(VerseTheme.paper)
}
#endif
