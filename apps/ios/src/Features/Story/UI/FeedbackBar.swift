import SwiftUI

struct FeedbackBar: View {
    let preference: FeedbackPreference?
    let isDisabled: Bool
    let onSelect: (FeedbackPreference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shape tomorrow")
                .font(.headline)
                .foregroundStyle(VerseTheme.ink)
            HStack(spacing: 8) {
                feedbackButton("More like this", icon: "hand.thumbsup", value: .moreLikeThis)
                feedbackButton("Less", icon: "hand.thumbsdown", value: .lessLikeThis)
                feedbackButton("Too basic", icon: "textformat.size.smaller", value: .tooBasic)
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
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    preference == value ? VerseTheme.blue.opacity(0.16) : VerseTheme.surface,
                    in: RoundedRectangle(cornerRadius: 10)
                )
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
