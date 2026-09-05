#if !VERSE_WIDGET
import SwiftUI

struct KeyboardLaunchLink: View {
    var body: some View {
        if let destination = URL(string: "verse://dictate") {
            Link(destination: destination) {
                Label("Speak", systemImage: "mic.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.10))
                    .background(Color(red: 1, green: 0.97, blue: 0.85), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("keyboard-open-dictation")
            .accessibilityHint("Opens Verse and starts recording")
        }
    }
}
#endif
