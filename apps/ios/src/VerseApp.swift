import SwiftUI

@main
@MainActor
struct VerseApp: App {
    @State private var store = TranscriptionStore()

    var body: some Scene {
        WindowGroup {
            TranscriptionHubView(store: store)
                .tint(.indigo)
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "en"))
        }
    }
}
