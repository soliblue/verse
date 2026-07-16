import Foundation
import SwiftData

@MainActor
final class EventFeedbackRepository {
    private let context: ModelContext
    private let api: APIClient
    private let encoder = JSONEncoder()
    private var isFlushing = false

    init(context: ModelContext, api: APIClient) {
        self.context = context
        self.api = api
    }

    func state(eventID: String, occurrenceID: String?) -> CachedEventFeedbackState {
        let key = CachedEventFeedbackState.key(eventID: eventID, occurrenceID: occurrenceID)
        var descriptor = FetchDescriptor<CachedEventFeedbackState>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1
        if let state = (try? context.fetch(descriptor))?.first { return state }
        let state = CachedEventFeedbackState(eventID: eventID, occurrenceID: occurrenceID)
        context.insert(state)
        try? context.save()
        return state
    }

    func update(
        eventID: String,
        occurrenceID: String?,
        kind: EventFeedbackKind,
        value: Bool = true
    ) async -> CachedEventFeedbackState {
        let state = state(eventID: eventID, occurrenceID: occurrenceID)
        switch kind {
        case .interested:
            state.interested = value
        case .going:
            state.going = value
        case .attended:
            state.attended = value
        case .loved:
            state.loved = value
            if value { state.attended = true }
        case .notForMe, .tooFar, .tooExpensive, .soldOut:
            state.dismissed = value
        case .moreFromVenue, .moreLikeThis:
            state.interested = value
        }
        state.updatedAt = Date()
        let feedback = EventFeedback(
            eventID: eventID,
            occurrenceID: occurrenceID,
            kind: kind,
            value: value
        )
        if let payload = try? encoder.encode(feedback) {
            context.insert(
                PendingMutation(
                    storyID: eventID,
                    path: APIEndpoint.eventFeedback,
                    payload: payload
                )
            )
        }
        try? context.save()
        await flushPending()
        return state
    }

    func flushPending() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        let path = APIEndpoint.eventFeedback
        while true {
            var descriptor = FetchDescriptor<PendingMutation>(
                predicate: #Predicate { $0.path == path && $0.failedAt == nil },
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
            case .success:
                context.delete(mutation)
                try? context.save()
            case .transportFailure:
                return
            case .httpFailure(let status):
                if [401, 403, 408, 429].contains(status) || 500..<600 ~= status { return }
                mutation.failedAt = Date()
                mutation.failureReason = "HTTP \(status)"
                try? context.save()
            }
        }
    }
}
