import Foundation
import SwiftData

@MainActor
final class EditionRepository {
    private let context: ModelContext
    private let api: APIClient
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(context: ModelContext, api: APIClient) {
        self.context = context
        self.api = api
    }

    func localToday() -> EditionPayload? {
        var descriptor = FetchDescriptor<CachedEdition>(
            predicate: #Predicate { $0.isCurrent == true },
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let cached = (try? context.fetch(descriptor))?.first,
            let edition = try? decoder.decode(EditionPayload.self, from: cached.payload)
        {
            return edition
        }
        guard
            let url = Bundle.main.url(forResource: "first-edition", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let edition = try? decoder.decode(EditionPayload.self, from: data)
        else { return nil }
        store(edition, data: data, isCurrent: true)
        return edition
    }

    func refreshToday() async -> EditionPayload? {
        guard let edition = await api.get(APIEndpoint.today, as: EditionPayload.self) else { return nil }
        store(edition, isCurrent: true)
        return edition
    }

    func localEdition(id: String) -> EditionPayload? {
        guard let cached = cachedEdition(id: id) else { return nil }
        return try? decoder.decode(EditionPayload.self, from: cached.payload)
    }

    func refreshEdition(id: String) async -> EditionPayload? {
        guard let edition = await api.get(APIEndpoint.edition(id), as: EditionPayload.self) else {
            return nil
        }
        store(edition, isCurrent: false)
        return edition
    }

    func summaries() async -> [EditionSummary] {
        let local = localSummaries()
        guard let response = await api.get(APIEndpoint.editions, as: EditionSummariesResponse.self) else {
            return local
        }
        store(response)
        return response.editions.sorted { $0.date > $1.date }
    }

    func localSummaries() -> [EditionSummary] {
        let descriptor = FetchDescriptor<CachedEdition>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        var summaries = Dictionary(
            uniqueKeysWithValues: (cachedIndex()?.editions ?? []).map { ($0.id, $0) }
        )
        for cached in (try? context.fetch(descriptor)) ?? [] {
            summaries[cached.id] = EditionSummary(
                id: cached.id,
                date: cached.date,
                title: cached.title,
                dek: cached.dek,
                generatedAt: cached.generatedAt,
                itemCount: cached.itemCount
            )
        }
        return summaries.values.sorted { $0.date > $1.date }
    }

    func stories(ids: Set<String>) -> [StoryItem] {
        let descriptor = FetchDescriptor<CachedEdition>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        var found: [String: StoryItem] = [:]
        for cached in (try? context.fetch(descriptor)) ?? [] {
            if let edition = try? decoder.decode(EditionPayload.self, from: cached.payload) {
                for story in edition.items where ids.contains(story.id) && found[story.id] == nil {
                    found[story.id] = story
                }
            }
        }
        return found.values.sorted { $0.publishedAt > $1.publishedAt }
    }

    func lastRefreshDate() -> Date? {
        var descriptor = FetchDescriptor<CachedEdition>(
            predicate: #Predicate { $0.isCurrent == true },
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.fetchedAt
    }

    func cachedEditionCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<CachedEdition>())) ?? 0
    }

    func clear() {
        try? context.delete(model: CachedEdition.self)
        try? context.delete(model: CachedEditionIndex.self)
        try? context.save()
    }

    private func cachedIndex() -> EditionSummariesResponse? {
        var descriptor = FetchDescriptor<CachedEditionIndex>(
            predicate: #Predicate { $0.key == "editions" }
        )
        descriptor.fetchLimit = 1
        guard let cached = (try? context.fetch(descriptor))?.first else { return nil }
        return try? decoder.decode(EditionSummariesResponse.self, from: cached.payload)
    }

    private func store(_ response: EditionSummariesResponse) {
        guard let data = try? encoder.encode(response) else { return }
        var descriptor = FetchDescriptor<CachedEditionIndex>(
            predicate: #Predicate { $0.key == "editions" }
        )
        descriptor.fetchLimit = 1
        if let cached = (try? context.fetch(descriptor))?.first {
            cached.payload = data
            cached.fetchedAt = Date()
        } else {
            context.insert(CachedEditionIndex(payload: data, fetchedAt: Date()))
        }
        try? context.save()
    }

    private func cachedEdition(id: String) -> CachedEdition? {
        var descriptor = FetchDescriptor<CachedEdition>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func store(_ edition: EditionPayload, isCurrent: Bool) {
        guard let data = try? encoder.encode(edition) else { return }
        store(edition, data: data, isCurrent: isCurrent)
    }

    private func store(_ edition: EditionPayload, data: Data, isCurrent: Bool) {
        if isCurrent {
            let currentDescriptor = FetchDescriptor<CachedEdition>(
                predicate: #Predicate { $0.isCurrent == true }
            )
            for cached in (try? context.fetch(currentDescriptor)) ?? [] {
                cached.isCurrent = false
            }
        }
        if let cached = cachedEdition(id: edition.id) {
            cached.date = edition.date
            cached.title = edition.title
            cached.dek = edition.dek
            cached.generatedAt = edition.generatedAt
            cached.itemCount = edition.items.count
            cached.payload = data
            cached.fetchedAt = Date()
            cached.isCurrent = isCurrent || cached.isCurrent
        } else {
            context.insert(
                CachedEdition(edition: edition, payload: data, fetchedAt: Date(), isCurrent: isCurrent)
            )
        }
        try? context.save()
    }
}
