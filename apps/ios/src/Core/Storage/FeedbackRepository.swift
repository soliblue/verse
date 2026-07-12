import Foundation
import SwiftData

@MainActor
final class FeedbackRepository {
    private let context: ModelContext
    private let api: APIClient
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var isFlushing = false

    init(context: ModelContext, api: APIClient) {
        self.context = context
        self.api = api
    }

    func state(for story: StoryItem) -> CachedStoryState {
        if let state = state(storyID: story.id) {
            mergeRemote(story, into: state)
            return state
        }
        let state = CachedStoryState(story: story)
        context.insert(state)
        try? context.save()
        return state
    }

    func savedStoryIDs() -> Set<String> {
        let descriptor = FetchDescriptor<CachedStoryState>(
            predicate: #Predicate { $0.isSaved == true }
        )
        return Set(((try? context.fetch(descriptor)) ?? []).map(\.storyID))
    }

    func mutationCounts() -> (pending: Int, failed: Int) {
        let pending = FetchDescriptor<PendingMutation>(
            predicate: #Predicate { $0.failedAt == nil }
        )
        let failed = FetchDescriptor<PendingMutation>(
            predicate: #Predicate { $0.failedAt != nil }
        )
        return (
            (try? context.fetchCount(pending)) ?? 0,
            (try? context.fetchCount(failed)) ?? 0
        )
    }

    func retryFailed() async {
        guard !isFlushing else { return }
        let descriptor = FetchDescriptor<PendingMutation>(
            predicate: #Predicate { $0.failedAt != nil }
        )
        for mutation in (try? context.fetch(descriptor)) ?? [] {
            mutation.failedAt = nil
            mutation.failureReason = nil
        }
        try? context.save()
        await flushPending()
    }

    func ingest(_ edition: EditionPayload) {
        for story in edition.items {
            _ = state(for: story)
        }
    }

    func update(story: StoryItem, kind: FeedbackKind, value: Bool) async -> CachedStoryState {
        let state = state(for: story)
        switch kind {
        case .saved:
            state.isSaved = value
        case .seen:
            state.isSeen = value
        case .moreLikeThis, .lessLikeThis, .tooBasic:
            let preference = FeedbackPreference(rawValue: kind.rawValue)
            state.preference = value ? preference : state.preference == preference ? nil : state.preference
        }
        state.hasLocalFeedbackActivity = true
        state.updatedAt = Date()
        if let payload = try? encoder.encode(FeedbackRequest(storyID: story.id, kind: kind, value: value)) {
            context.insert(PendingMutation(storyID: story.id, path: APIEndpoint.feedback, payload: payload))
        }
        try? context.save()
        await flushPending()
        return state
    }

    func requestDeepDive(story: StoryItem) async -> CachedStoryState {
        let state = state(for: story)
        state.deepDiveStatus = .queued
        state.deepDiveRequestedAt = Date().ISO8601Format()
        state.updatedAt = Date()
        if let payload = try? encoder.encode(DeepDiveRequest(storyID: story.id)) {
            context.insert(PendingMutation(storyID: story.id, path: APIEndpoint.deepDives, payload: payload))
        }
        try? context.save()
        await flushPending()
        return state
    }

    func flushPending() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        while true {
            var descriptor = FetchDescriptor<PendingMutation>(
                predicate: #Predicate { $0.failedAt == nil },
                sortBy: [SortDescriptor(\.createdAt)]
            )
            descriptor.fetchLimit = 1
            guard let mutation = (try? context.fetch(descriptor))?.first else { return }
            switch await api.sendResult(
                    path: mutation.path,
                    method: "POST",
                    payload: mutation.payload,
                    idempotencyKey: mutation.id
                ) {
            case .success(let response):
                if !hasNewerMutation(than: mutation) {
                    apply(response: response, for: mutation)
                }
                context.delete(mutation)
                try? context.save()
            case .transportFailure:
                return
            case .httpFailure(let status):
                if [401, 403, 408, 429].contains(status) || 500..<600 ~= status {
                    return
                }
                mutation.failedAt = Date()
                mutation.failureReason = "HTTP \(status)"
                try? context.save()
            }
        }
    }

    private func state(storyID: String) -> CachedStoryState? {
        var descriptor = FetchDescriptor<CachedStoryState>(
            predicate: #Predicate { $0.storyID == storyID }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func hasNewerMutation(than mutation: PendingMutation) -> Bool {
        let storyID = mutation.storyID
        let createdAt = mutation.createdAt
        var descriptor = FetchDescriptor<PendingMutation>(
            predicate: #Predicate {
                $0.storyID == storyID && $0.createdAt > createdAt
            }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first != nil
    }

    private func mergeRemote(_ story: StoryItem, into state: CachedStoryState) {
        if !state.hasLocalFeedbackActivity, let feedback = story.feedback {
            state.isSaved = feedback.saved
            state.isSeen = feedback.seen
            state.preference = feedback.preference
        }
        if let deepDive = story.deepDive, deepDive.status != .notRequested {
            let remoteRequestedAt = TimestampParsing.date(deepDive.requestedAt)
            let localRequestedAt = TimestampParsing.date(state.deepDiveRequestedAt)
            let isNewerRequest = remoteRequestedAt.map {
                $0 > (localRequestedAt ?? .distantPast)
            } == true
            let isSameRequest = (remoteRequestedAt != nil && remoteRequestedAt == localRequestedAt)
                || (remoteRequestedAt == nil && localRequestedAt == nil
                    && deepDive.requestedAt == state.deepDiveRequestedAt)
            let advancesSameRequest = isSameRequest
                && state.deepDiveStatus == .queued
                && [.ready, .failed].contains(deepDive.status)
            if state.deepDiveStatus == .notRequested || isNewerRequest || advancesSameRequest
            {
                apply(deepDive: deepDive, to: state)
            }
        }
        try? context.save()
    }

    private func apply(response: Data, for mutation: PendingMutation) {
        if mutation.path == APIEndpoint.feedback,
            let decoded = try? decoder.decode(FeedbackResponse.self, from: response),
            let state = state(storyID: decoded.storyID)
        {
            state.isSaved = decoded.feedback.saved
            state.isSeen = decoded.feedback.seen
            state.preference = decoded.feedback.preference
            state.updatedAt = Date()
        }
        if mutation.path == APIEndpoint.deepDives,
            let decoded = try? decoder.decode(DeepDiveResponse.self, from: response),
            let state = state(storyID: decoded.storyID)
        {
            apply(deepDive: decoded.deepDive, to: state)
        }
    }

    private func apply(deepDive: DeepDiveState, to state: CachedStoryState) {
        state.deepDiveStatus = deepDive.status
        state.deepDiveRequestedAt = deepDive.requestedAt ?? state.deepDiveRequestedAt
        state.deepDiveTitle = deepDive.title
        state.deepDiveBody = deepDive.body
        state.citations = deepDive.citations
        state.updatedAt = Date()
    }
}
