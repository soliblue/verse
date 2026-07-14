import SwiftUI

struct StoryToolbar: View {
    let sourceURL: URL
    let isSaved: Bool
    let isDisabled: Bool
    let onBack: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(VerseTheme.border, lineWidth: 1)
                    }
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("story-back")

            Spacer()

            HStack(spacing: 2) {
                Button(action: onSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .frame(width: 44, height: 44)
                }
                .disabled(isDisabled)
                .accessibilityLabel(isSaved ? "Remove bookmark" : "Save story")
                .accessibilityIdentifier("story-save")

                ShareLink(item: sourceURL) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Share original story")
                .accessibilityIdentifier("story-share")
            }
            .padding(.horizontal, 2)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(VerseTheme.border, lineWidth: 1)
            }
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(VerseTheme.ink)
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}
