import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    var serverURL: String
    var deviceSecret: String
    private(set) var connectionStatus = ConnectionStatus.idle
    private(set) var saveMessage: String?

    var canSave: Bool {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        guard let url = URL(string: trimmed) else { return false }
        return ["http", "https"].contains(url.scheme?.lowercased() ?? "") && url.host != nil
    }

    init(configuration: ServerConfiguration) {
        serverURL = configuration.serverURLString
        deviceSecret = configuration.deviceSecret
    }

    @discardableResult
    func save(configuration: ServerConfiguration) -> Bool {
        guard canSave else {
            saveMessage = "Enter a full HTTP or HTTPS URL."
            return false
        }
        let saved = configuration.save(serverURLString: serverURL, deviceSecret: deviceSecret)
        saveMessage = saved
            ? "Connection settings saved."
            : "The server URL was saved, but the secret could not be stored in Keychain."
        connectionStatus = .idle
        return saved
    }

    func test(
        configuration: ServerConfiguration,
        api: APIClient,
        feedback: FeedbackRepository,
        topics: TopicsRepository
    ) async {
        guard save(configuration: configuration) else {
            connectionStatus = .failed
            return
        }
        guard configuration.isConfigured else {
            connectionStatus = .failed
            saveMessage = "Add a server URL before testing."
            return
        }
        connectionStatus = .testing
        if let health = await api.get(APIEndpoint.health, as: HealthResponse.self),
            health.status == "ok", health.database == "ok"
        {
            if let currentEditionID = health.currentEditionID {
                if let edition = await api.get(APIEndpoint.today, as: EditionPayload.self),
                    edition.id == currentEditionID
                {
                    connectionStatus = .connected
                    saveMessage = "Connected. Current edition: \(currentEditionID)."
                } else {
                    connectionStatus = .failed
                    saveMessage =
                        "The VPS is healthy, but Verse could not read the current edition. "
                        + "Check the device secret and server contract."
                }
            } else {
                connectionStatus = .connected
                saveMessage = "Connected. No current server edition yet."
            }
        } else {
            connectionStatus = .failed
            saveMessage = "Verse could not reach a healthy VPS at this address."
        }
        if connectionStatus == .connected {
            await feedback.flushPending()
            _ = await topics.syncPending()
        }
    }

}
