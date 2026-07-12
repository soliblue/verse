import Foundation
import SwiftData

@MainActor
final class TopicsRepository {
    private let context: ModelContext
    private let api: APIClient
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var isFetching = false
    private var isSyncing = false

    init(context: ModelContext, api: APIClient) {
        self.context = context
        self.api = api
    }

    func load() async -> TopicList? {
        if entry()?.needsSync == true {
            _ = await syncPending()
            return local() ?? bundled()
        }
        let local = local()
        guard !isFetching else { return local ?? bundled() }
        isFetching = true
        defer { isFetching = false }
        let revision = entry()?.revision ?? 0
        if let remote = await api.get(APIEndpoint.topics, as: TopicList.self) {
            if let current = entry(), current.revision == revision, !current.needsSync {
                storeRemote(remote, revision: revision)
                return remote
            }
            if entry() == nil, revision == 0 {
                storeRemote(remote, revision: revision)
                return remote
            }
        }
        return self.local() ?? local ?? bundled()
    }

    func save(_ list: TopicList) async -> Bool {
        markDirty(list)
        return await syncPending()
    }

    func syncPending() async -> Bool {
        guard !isSyncing else { return false }
        isSyncing = true
        defer { isSyncing = false }
        while let cached = entry(), cached.needsSync {
            let revision = cached.revision
            guard
                let list = try? decoder.decode(TopicList.self, from: cached.payload),
                let response = await api.put(APIEndpoint.topics, body: list, as: TopicList.self)
            else { return false }
            if let current = entry(), current.revision == revision {
                storeRemote(response, revision: current.revision)
            }
        }
        return true
    }

    private func entry() -> CachedTopics? {
        var descriptor = FetchDescriptor<CachedTopics>(predicate: #Predicate { $0.key == "topics" })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func local() -> TopicList? {
        entry().flatMap { try? decoder.decode(TopicList.self, from: $0.payload) }
    }

    private func bundled() -> TopicList? {
        guard
            let url = Bundle.main.url(forResource: "default-topics", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let list = try? decoder.decode(TopicList.self, from: data)
        else { return nil }
        storeRemote(list, revision: 0)
        return list
    }

    private func markDirty(_ list: TopicList) {
        guard let data = try? encoder.encode(list) else { return }
        if let cached = entry() {
            cached.payload = data
            cached.fetchedAt = Date()
            cached.needsSync = true
            cached.revision += 1
        } else {
            context.insert(
                CachedTopics(payload: data, fetchedAt: Date(), needsSync: true, revision: 1)
            )
        }
        try? context.save()
    }

    private func storeRemote(_ list: TopicList, revision: Int) {
        guard let data = try? encoder.encode(list) else { return }
        if let cached = entry() {
            cached.payload = data
            cached.fetchedAt = Date()
            cached.needsSync = false
            cached.revision = revision
        } else {
            context.insert(
                CachedTopics(payload: data, fetchedAt: Date(), needsSync: false, revision: revision)
            )
        }
        try? context.save()
    }
}
