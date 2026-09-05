import Foundation
import Security

enum VerseBridge {
    static let defaultBaseURL = "https://verse.soli.blue"

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

    static var isRecording: Bool {
        get { read("isRecording") == "true" }
        set { write(String(newValue), key: "isRecording") }
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
        get { read("model") ?? "small" }
        set { write(newValue, key: "model") }
    }

    static var language: String {
        get { read("language") ?? "auto" }
        set { write(newValue, key: "language") }
    }

    static func send(_ action: String) {
        commandAction = action
        commandID = UUID().uuidString
    }

    private static func query(_ key: String) -> [String: Any] {
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

    private static func read(_ key: String) -> String? {
        var values = query(key)
        values[kSecReturnData as String] = true
        values[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(values as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String, key: String) {
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
