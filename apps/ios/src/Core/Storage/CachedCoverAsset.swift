import Foundation
import SwiftData

@Model
final class CachedCoverAsset {
    @Attribute(.unique) var url: String
    @Attribute(.externalStorage) var data: Data
    var fetchedAt: Date

    init(url: URL, data: Data) {
        self.url = url.absoluteString
        self.data = data
        fetchedAt = Date()
    }
}
