import Foundation

enum NightjarJob: String, CaseIterable, Identifiable, Sendable {
    case articles
    case events

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
