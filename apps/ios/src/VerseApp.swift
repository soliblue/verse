import SwiftUI

@main
@MainActor
struct VerseApp: App {
    @State private var store = TranscriptionStore.shared

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--keyboard-ui-testing") || ProcessInfo.processInfo.arguments.contains("--system-keyboard-ui-testing") {
                KeyboardPreviewScreen()
                    .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--keyboard-dark-ui-testing") ? .dark : .light)
            } else {
                hub
            }
            #else
            hub
            #endif
        }
    }

    private var hub: some View {
        TranscriptionHubView(store: store)
            .tint(Color(red: 0.12, green: 0.16, blue: 0.10))
            .preferredColorScheme(.light)
            .environment(\.locale, Locale(identifier: "en"))
    }
}
