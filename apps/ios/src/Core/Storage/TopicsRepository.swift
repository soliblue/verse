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

    func load() async -> PreferencesDocument? {
        if entry()?.needsSync == true {
            _ = await syncPending()
            return local() ?? bundled()
        }
        let local = local()
        guard !isFetching else { return local ?? bundled() }
        isFetching = true
        defer { isFetching = false }
        let revision = entry()?.revision ?? 0
        if let remote = await api.get(APIEndpoint.preferences, as: PreferencesDocument.self) {
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

    func save(_ document: PreferencesDocument) async -> TopicsSaveResult {
        markDirty(document)
        return await syncPendingResult()
    }

    func syncPending() async -> Bool {
        await syncPendingResult() == .synced
    }

    private func syncPendingResult() async -> TopicsSaveResult {
        guard !isSyncing else { return .pending }
        isSyncing = true
        defer { isSyncing = false }
        while let cached = entry(), cached.needsSync {
            let revision = cached.revision
            guard let document = document(from: cached.payload) else { return .pending }
            let result = await api.putResult(APIEndpoint.preferences, body: document)
            let response: PreferencesDocument
            switch result {
            case .success(let data):
                guard let decoded = try? decoder.decode(PreferencesDocument.self, from: data) else {
                    return .pending
                }
                response = decoded
            case .httpFailure(let status) where [400, 413, 415, 422].contains(status):
                return .rejected
            case .httpFailure, .transportFailure:
                return .pending
            }
            if let current = entry(), current.revision == revision {
                storeRemote(response, revision: current.revision)
            }
        }
        return .synced
    }

    private func entry() -> CachedTopics? {
        var descriptor = FetchDescriptor<CachedTopics>(predicate: #Predicate { $0.key == "topics" })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func local() -> PreferencesDocument? {
        entry().flatMap { document(from: $0.payload) }
    }

    private func bundled() -> PreferencesDocument? {
        guard
            let url = Bundle.main.url(forResource: "default-topics", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let list = try? decoder.decode(TopicList.self, from: data)
        else { return nil }
        let document = PreferencesDocument(topics: list.topics)
        storeRemote(document, revision: 0)
        return document
    }

    private func markDirty(_ document: PreferencesDocument) {
        guard let data = try? encoder.encode(document) else { return }
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

    private func storeRemote(_ document: PreferencesDocument, revision: Int) {
        guard let data = try? encoder.encode(document) else { return }
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

    private func document(from data: Data) -> PreferencesDocument? {
        if let document = try? decoder.decode(PreferencesDocument.self, from: data) {
            return document
        }
        guard let legacy = try? decoder.decode(TopicList.self, from: data) else { return nil }
        return PreferencesDocument(topics: legacy.topics)
    }
}
