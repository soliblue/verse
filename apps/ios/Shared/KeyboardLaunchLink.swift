#if !VERSE_WIDGET
import SwiftUI

struct KeyboardLaunchLink: View {
    var body: some View {
        if let destination = URL(string: "verse://dictate") {
            Link(destination: destination) {
                Image(systemName: "power")
                    .font(.system(size: 21, weight: .medium))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(Color(red: 0.89, green: 0.29, blue: 0.04))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("keyboard-open-dictation")
            .accessibilityLabel("Activate dictation")
            .accessibilityHint("Opens Verse and starts recording")
        }
    }
}
#endif
