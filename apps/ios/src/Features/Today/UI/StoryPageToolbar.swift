import SwiftUI

struct StoryPageToolbar: View {
    let number: Int
    let sourceURL: URL
    let isSaved: Bool
    let preference: FeedbackPreference?
    let deepDiveStatus: DeepDiveStatus
    let isDisabled: Bool
    let onSave: () -> Void
    let onPreference: (FeedbackPreference) -> Void
    let onDeepDive: () -> Void

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
            .accessibilityIdentifier("reader-save-\(number)")

            StoryActionsMenu(
                sourceURL: sourceURL,
                preference: preference,
                deepDiveStatus: deepDiveStatus,
                isDisabled: isDisabled,
                onPreference: onPreference,
                onDeepDive: onDeepDive,
                accessibilityIdentifier: "reader-actions-\(number)"
            )
        }
        .font(.system(size: VerseTokens.Icon.m, weight: .medium))
        .foregroundStyle(VerseTheme.ink)
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}
