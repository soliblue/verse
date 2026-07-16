import Foundation
import SwiftData

@MainActor
final class VenueFeedbackRepository {
    private let context: ModelContext
    private let api: APIClient
    private let encoder = JSONEncoder()
    private var isFlushing = false

    init(context: ModelContext, api: APIClient) {
        self.context = context
        self.api = api
    }

    func update(venueID: String, kind: VenueFeedbackKind, value: Bool = true) async {
        let feedback = VenueFeedback(venueID: venueID, kind: kind, value: value)
        if let payload = try? encoder.encode(feedback) {
            context.insert(
                PendingMutation(
                    storyID: venueID,
                    path: APIEndpoint.venueFeedback,
                    payload: payload
                )
            )
        }
        try? context.save()
        await flushPending()
    }

    func flushPending() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        let path = APIEndpoint.venueFeedback
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
