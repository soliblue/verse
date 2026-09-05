import Foundation
import Security

enum VerseBridge {
    static let defaultBaseURL = "https://verse.soli.blue"

    static var sessionDuration: Double {
        get {
            let duration = Double(read("sessionDuration") ?? "900") ?? 900
            return [300.0, 900.0, 3600.0].contains(duration) ? duration : 900
        }
        set { write(String(newValue), key: "sessionDuration") }
    }

    static var pendingInsertionJobID: String {
        get { read("pendingInsertionJobID") ?? "" }
        set { write(newValue, key: "pendingInsertionJobID") }
    }

    static var insertionTranscriptID: String {
        get { read("insertionTranscriptID") ?? "" }
        set { write(newValue, key: "insertionTranscriptID") }
    }

    static var insertionReadyAt: Double {
        get { Double(read("insertionReadyAt") ?? "0") ?? 0 }
        set { write(String(newValue), key: "insertionReadyAt") }
    }

    static var lastInsertedTranscriptID: String {
        get { read("lastInsertedTranscriptID") ?? "" }
        set { write(newValue, key: "lastInsertedTranscriptID") }
    }

    static var baseURL: String {
        get { read("baseURL") ?? defaultBaseURL }
        set { write(newValue, key: "baseURL") }
    }

    static var token: String {
        get { read("token") ?? "" }
        set { write(newValue, key: "token") }
    }

    static var commandID: String {
        get { read("commandID") ?? "" }
        set { write(newValue, key: "commandID") }
    }

    static var commandAction: String {
        get { read("commandAction") ?? "" }
        set { write(newValue, key: "commandAction") }
    }

    static var acknowledgedCommandID: String {
        get { read("acknowledgedCommandID") ?? "" }
        set { write(newValue, key: "acknowledgedCommandID") }
    }

    static var sessionExpiresAt: Double {
        get { Double(read("sessionExpiresAt") ?? "0") ?? 0 }
        set { write(String(newValue), key: "sessionExpiresAt") }
    }

    static var sessionHeartbeatAt: Double {
        get { Double(read("sessionHeartbeatAt") ?? "0") ?? 0 }
        set { write(String(newValue), key: "sessionHeartbeatAt") }
    }

    static var isRecording: Bool {
        get { read("isRecording") == "true" }
        set { write(String(newValue), key: "isRecording") }
    }

    static var audioLevel: Double {
        get { readAudioLevel() }
        set { publishAudioLevel(newValue) }
    }

    nonisolated static func readAudioLevel() -> Double {
        let value = Double(read("audioLevel") ?? "0") ?? 0
        return value.isFinite ? min(1, max(0, value)) : 0
    }

    nonisolated static func publishAudioLevel(_ value: Double) {
        write(String(value.isFinite ? min(1, max(0, value)) : 0), key: "audioLevel")
    }

    static var transcriptID: String {
        get { read("transcriptID") ?? "" }
        set { write(newValue, key: "transcriptID") }
    }

    static var transcriptText: String {
        get { read("transcriptText") ?? "" }
        set { write(newValue, key: "transcriptText") }
    }

    static var statusText: String {
        get { read("statusText") ?? "" }
        set { write(newValue, key: "statusText") }
    }

    static var errorText: String {
        get { read("errorText") ?? "" }
        set { write(newValue, key: "errorText") }
    }

    static var pendingJobID: String {
        get { read("pendingJobID") ?? "" }
        set { write(newValue, key: "pendingJobID") }
    }

    static var model: String {
        get { read("model") ?? "medium" }
        set { write(newValue, key: "model") }
    }

    static var language: String {
        get { read("language") ?? "auto" }
        set { write(newValue, key: "language") }
    }

    @discardableResult
    static func send(_ action: String) -> String {
        let identifier = UUID().uuidString
        commandAction = action
        commandID = identifier
        return identifier
    }

    nonisolated static func publishTranscriptionResult(id: String, statusCode: Int, state: String?, text: String?, error: String?) {
        guard read("pendingJobID") == id, !Task.isCancelled else { return }
        if statusCode == 401 {
            write("Your device token was not accepted. Check Verse Settings.", key: "errorText")
        } else if statusCode == 200, state == "completed" {
            write(text ?? "", key: "transcriptText")
            write(id, key: "transcriptID")
            write("", key: "errorText")
            if read("pendingInsertionJobID") == id {
                write(id, key: "insertionTranscriptID")
                write(String(Date().timeIntervalSince1970), key: "insertionReadyAt")
                write("", key: "pendingInsertionJobID")
            }
            write("", key: "pendingJobID")
            write("", key: "statusText")
        } else if statusCode == 200, state == "failed" {
            write(error ?? "Transcription failed. Try again in Verse.", key: "errorText")
            write("", key: "pendingJobID")
            write("", key: "pendingInsertionJobID")
            write("", key: "statusText")
        }
    }

    nonisolated static func snapshot() -> [String: String] {
        var values = query("")
        values.removeValue(forKey: kSecAttrAccount as String)
        values[kSecReturnData as String] = true
        values[kSecReturnAttributes as String] = true
        values[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        guard SecItemCopyMatching(values as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return [:] }
        return items.reduce(into: [:]) { snapshot, item in
            if let key = item[kSecAttrAccount as String] as? String,
               let data = item[kSecValueData as String] as? Data,
               let value = String(data: data, encoding: .utf8) {
                snapshot[key] = value
            }
        }
    }

    nonisolated private static func query(_ key: String) -> [String: Any] {
        var values: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "soli.verse.bridge",
            kSecAttrAccount as String: key
        ]
        if let group = Bundle.main.object(forInfoDictionaryKey: "VerseKeychainAccessGroup") as? String,
           !group.contains("$(") {
            values[kSecAttrAccessGroup as String] = group
        }
        return values
    }

    nonisolated private static func read(_ key: String) -> String? {
        var values = query(key)
        values[kSecReturnData as String] = true
        values[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(values as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    nonisolated private static func write(_ value: String, key: String) {
        let values = query(key)
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(values as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            SecItemAdd(values.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
    }
}
