import Foundation
import SwiftData

@Model
final class CachedStoryState {
    @Attribute(.unique) var storyID: String
    var isSaved: Bool
    var isSeen: Bool
    var preferenceRaw: String?
    var deepDiveStatusRaw: String
    var deepDiveRequestedAt: String?
    var deepDiveTitle: String?
    var deepDiveBody: String?
    var deepDiveCitations: Data
    var hasLocalFeedbackActivity = false
    var updatedAt: Date

    var preference: FeedbackPreference? {
        get { preferenceRaw.flatMap(FeedbackPreference.init(rawValue:)) }
        set { preferenceRaw = newValue?.rawValue }
    }

    var deepDiveStatus: DeepDiveStatus {
        get { DeepDiveStatus(rawValue: deepDiveStatusRaw) ?? .notRequested }
        set { deepDiveStatusRaw = newValue.rawValue }
    }

    var citations: [Citation] {
        get { (try? JSONDecoder().decode([Citation].self, from: deepDiveCitations)) ?? [] }
        set { deepDiveCitations = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8) }
    }

    init(story: StoryItem) {
        let deepDive = story.resolvedDeepDive
        storyID = story.id
        isSaved = story.resolvedFeedback.saved
        isSeen = story.resolvedFeedback.seen
        preferenceRaw = story.resolvedFeedback.preference?.rawValue
        deepDiveStatusRaw = deepDive.status.rawValue
        deepDiveRequestedAt = deepDive.requestedAt
        deepDiveTitle = deepDive.title
        deepDiveBody = deepDive.body
        deepDiveCitations = (try? JSONEncoder().encode(deepDive.citations)) ?? Data("[]".utf8)
        hasLocalFeedbackActivity = false
        updatedAt = Date()
    }
}
