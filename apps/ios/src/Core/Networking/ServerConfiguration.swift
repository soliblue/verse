import Foundation
import Observation

@MainActor
@Observable
final class ServerConfiguration {
    private(set) var serverURLString: String
    private(set) var deviceSecret: String

    var serverURL: URL? {
        let trimmed = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            url.host != nil
        else { return nil }
        return url
    }

    var isConfigured: Bool { serverURL != nil }

    init(defaults: UserDefaults = .standard) {
        serverURLString = defaults.string(forKey: "morrow.serverURL") ?? ""
        deviceSecret = KeychainStore.value(for: "device-secret")
    }

    nonisolated deinit {}

    func save(serverURLString: String, deviceSecret: String, defaults: UserDefaults = .standard) -> Bool {
        let normalized = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.serverURLString = normalized
        self.deviceSecret = deviceSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(normalized, forKey: "morrow.serverURL")
        return KeychainStore.set(self.deviceSecret, for: "device-secret")
    }
}
