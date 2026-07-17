import Foundation

enum SettingsPrompt: String, CaseIterable, Identifiable {
    case topics
    case articles
    case events

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
