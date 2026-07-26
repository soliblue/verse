import SwiftUI

struct StoryPageToolbar: View {
    let preference: FeedbackPreference?
    let isDisabled: Bool
    let foregroundColor: Color
    let onPreference: (FeedbackPreference) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button {
                onPreference(.moreLikeThis)
            } label: {
                Image(systemName: preference == .moreLikeThis ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isDisabled)
            .accessibilityLabel(preference == .moreLikeThis ? "Remove like" : "Like")
            .accessibilityIdentifier("reader-like")

            Button {
                onPreference(.lessLikeThis)
            } label: {
                Image(systemName: preference == .lessLikeThis ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isDisabled)
            .accessibilityLabel(preference == .lessLikeThis ? "Remove dislike" : "Dislike")
            .accessibilityIdentifier("reader-dislike")
        }
        .font(.system(size: VerseTokens.Icon.m, weight: .medium))
        .foregroundStyle(foregroundColor)
        .buttonStyle(.plain)
    }
}
