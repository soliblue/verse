import ActivityKit
import Foundation

nonisolated struct DictationActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var phase: String
        var startedAt: Date
    }
}
