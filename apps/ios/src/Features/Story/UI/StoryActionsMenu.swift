import SwiftUI

struct StoryActionsMenu: View {
    let sourceURL: URL
    let preference: FeedbackPreference?
    let deepDiveStatus: DeepDiveStatus
    let isDisabled: Bool
    let onPreference: (FeedbackPreference) -> Void
    let onDeepDive: () -> Void
    var onShowDetails: (() -> Void)?
    var accessibilityIdentifier = "story-actions"

    var body: some View {
        Menu {
            Section("Feedback") {
                preferenceButton("More like this", icon: "hand.thumbsup", value: .moreLikeThis)
                preferenceButton("Less like this", icon: "hand.thumbsdown", value: .lessLikeThis)
                preferenceButton("Too basic", icon: "textformat.size.smaller", value: .tooBasic)
            }

            Section {
                switch deepDiveStatus {
                case .notRequested:
                    Button("Request deep dive", systemImage: "moon.stars", action: onDeepDive)
                case .queued:
                    Label("Deep dive queued", systemImage: "clock")
                case .ready:
                    if let onShowDetails {
                        Button("View deep dive", systemImage: "moon.stars", action: onShowDetails)
                    } else {
                        Label("Deep dive ready", systemImage: "checkmark")
                    }
                case .failed:
                    Button("Retry deep dive", systemImage: "arrow.clockwise", action: onDeepDive)
                }

                if let onShowDetails, deepDiveStatus != .ready {
                    Button("Story details", systemImage: "info.circle", action: onShowDetails)
                }
            }

            Section {
                Link(destination: sourceURL) {
                    Label("Open original", systemImage: "arrow.up.right")
                }
                ShareLink(item: sourceURL) {
                    Label("Share original", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel("Story actions")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func preferenceButton(
        _ title: String,
        icon: String,
        value: FeedbackPreference
    ) -> some View {
        Button {
            onPreference(value)
        } label: {
            Label(title, systemImage: preference == value ? "checkmark" : icon)
        }
    }
}
