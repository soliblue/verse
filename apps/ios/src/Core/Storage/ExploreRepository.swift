import Foundation
import SwiftData

@MainActor
final class ExploreRepository {
    private let context: ModelContext
    private let api: APIClient
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(context: ModelContext, api: APIClient) {
        self.context = context
        self.api = api
    }

    func local() -> ExplorePayload? {
        var descriptor = FetchDescriptor<CachedExplore>(
            predicate: #Predicate { $0.key == "current" },
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let data = (try? context.fetch(descriptor))?.first?.payload,
            let payload = try? decoder.decode(ExplorePayload.self, from: data)
        {
            return payload
        }
        guard
            let url = Bundle.main.url(forResource: "first-explore", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let payload = try? decoder.decode(ExplorePayload.self, from: data)
        else { return nil }
        store(payload, data: data)
        return payload
    }

    func refresh() async -> ExplorePayload? {
        guard let payload = await api.get(APIEndpoint.explore, as: ExplorePayload.self) else {
            return nil
        }
        store(payload)
        return payload
    }

    func events(ids: [String]) -> [EventItem] {
        guard !ids.isEmpty else { return [] }
        guard let payload = local() else { return [] }
        let wanted = Set(ids)
        return payload.allEvents.filter { wanted.contains($0.occurrence.id) }
    }

    func clear() {
        try? context.delete(model: CachedExplore.self)
        try? context.save()
    }

    private func store(_ payload: ExplorePayload) {
        guard let data = try? encoder.encode(payload) else { return }
        store(payload, data: data)
    }

    private func store(_ payload: ExplorePayload, data: Data) {
        var descriptor = FetchDescriptor<CachedExplore>(
            predicate: #Predicate { $0.key == "current" }
        )
        descriptor.fetchLimit = 1
        if let cached = (try? context.fetch(descriptor))?.first {
            cached.payload = data
            cached.fetchedAt = Date()
        } else {
            context.insert(CachedExplore(payload: data, fetchedAt: Date()))
        }
        try? context.save()
    }
}
