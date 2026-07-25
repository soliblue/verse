import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class StoryImageStore {
    private(set) var image: UIImage?

    func load(url: URL, api: APIClient, context: ModelContext) async {
        let urlString = url.absoluteString
        var descriptor = FetchDescriptor<CachedCoverAsset>(
            predicate: #Predicate { $0.url == urlString }
        )
        descriptor.fetchLimit = 1
        if let cached = (try? context.fetch(descriptor))?.first {
            image = UIImage(data: cached.data)
        } else if let data = await api.data(from: url), let decoded = UIImage(data: data) {
            context.insert(CachedCoverAsset(url: url, data: data))
            try? context.save()
            image = decoded
        }
    }
}
