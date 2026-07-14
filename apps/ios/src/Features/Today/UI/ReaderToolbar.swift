import SwiftUI

struct ReaderToolbar: View {
    let statusMessage: String?
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VerseMark()
                Spacer()
                Button(action: onRefresh) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh edition")
                .accessibilityIdentifier("verse-reader-refresh")
            }
            .padding(.leading, 16)
            .padding(.trailing, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)

            if let statusMessage {
                Label(statusMessage, systemImage: "wifi.slash")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(VerseTheme.ink)
                    .lineLimit(2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.thinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#if DEBUG
#Preview("Reader toolbar") {
    ReaderToolbar(statusMessage: "Using the downloaded edition.", isRefreshing: false) {}
        .padding()
        .background(VerseTheme.paper)
}
#endif
