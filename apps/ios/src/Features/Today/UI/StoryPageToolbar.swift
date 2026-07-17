import SwiftUI

struct StoryPageToolbar: View {
    @Binding var selectedTab: AppTab
    let sourceURL: URL
    let isSaved: Bool
    let preference: FeedbackPreference?
    let deepDiveStatus: DeepDiveStatus
    let isDisabled: Bool
    let foregroundColor: Color
    let onSave: () -> Void
    let onPreference: (FeedbackPreference) -> Void
    let onDeepDive: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            AppNavigationMenu(selection: $selectedTab)
            Spacer()
            Button(action: onSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isDisabled)
            .accessibilityLabel(isSaved ? "Remove bookmark" : "Save story")
            .accessibilityIdentifier("reader-save")

            StoryActionsMenu(
                sourceURL: sourceURL,
                preference: preference,
                deepDiveStatus: deepDiveStatus,
                isDisabled: isDisabled,
                onPreference: onPreference,
                onDeepDive: onDeepDive,
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
