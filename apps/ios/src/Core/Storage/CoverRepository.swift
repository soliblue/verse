import Foundation
import SwiftData

@MainActor
final class CoverRepository {
    private let context: ModelContext
    private let api: APIClient

    init(context: ModelContext, api: APIClient) {
        self.context = context
        self.api = api
    }

    func data(for url: URL) async -> Data? {
        let value = url.absoluteString
        var descriptor = FetchDescriptor<CachedCoverAsset>(
            predicate: #Predicate { $0.url == value }
        )
        descriptor.fetchLimit = 1
        if let data = (try? context.fetch(descriptor))?.first?.data {
            return data
        }
        guard let data = await api.data(from: url) else { return nil }
        context.insert(CachedCoverAsset(url: url, data: data))
        try? context.save()
        return data
    }
}
