import SwiftUI

struct StoryPageToolbar: View {
    let sourceURL: URL
    let isSaved: Bool
    let preference: FeedbackPreference?
    let deepDiveStatus: DeepDiveStatus
    let isDisabled: Bool
    let foregroundColor: Color
    let onSave: () -> Void
    let onPreference: (FeedbackPreference) -> Void
    let onDeepDive: () -> Void
    let onShowDetails: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Button(action: onSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isDisabled)
            .accessibilityLabel(isSaved ? "Remove bookmark" : "Save story")
            .accessibilityIdentifier("reader-save")

            Button {
                onPreference(.moreLikeThis)
            } label: {
                Image(systemName: preference == .moreLikeThis ? "heart.fill" : "heart")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isDisabled)
            .accessibilityLabel(preference == .moreLikeThis ? "Unlike story" : "Like story")
            .accessibilityIdentifier("reader-like")

            StoryActionsMenu(
                sourceURL: sourceURL,
                preference: preference,
                deepDiveStatus: deepDiveStatus,
                isDisabled: isDisabled,
                onPreference: onPreference,
                onDeepDive: onDeepDive,
                onShowDetails: onShowDetails,
                accessibilityIdentifier: "reader-actions"
            )
        }
        .font(.system(size: VerseTokens.Icon.m, weight: .medium))
        .foregroundStyle(foregroundColor)
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}
