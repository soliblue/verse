import AppIntents

@available(iOS 18.0, *)
struct VerseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: ["Dictate with \(.applicationName)", "Toggle dictation in \(.applicationName)"],
            shortTitle: "Toggle dictation",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: EndDictationSessionIntent(),
            phrases: ["End my \(.applicationName) session"],
            shortTitle: "End session",
            systemImageName: "mic.slash.fill"
        )
    }
}
