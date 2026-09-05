import SwiftUI

@main
@MainActor
struct VerseApp: App {
    @State private var store = TranscriptionStore.shared

    var body: some Scene {
        WindowGroup {
            TranscriptionHubView(store: store)
                .tint(Color(red: 0.12, green: 0.16, blue: 0.10))
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "en"))
        }
    }
}
