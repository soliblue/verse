import Foundation
import Security

enum VerseBridge {
    static let defaultBaseURL = "https://verse.soli.blue"
    private struct RewriteLease: Codable { let owner: String; let started: Double }

    static var onDeviceTranscriptionEnabled: Bool {
        get { read("onDeviceTranscriptionEnabled") != "false" }
        set { write(String(newValue), key: "onDeviceTranscriptionEnabled") }
    }

    static var localModel: String {
        get { read("localModel") ?? "medium" }
        set { write(newValue, key: "localModel") }
    }

    static var localInstalledModels: String {
        get { read("localInstalledModels") ?? "" }
        set { write(newValue, key: "localInstalledModels") }
    }

    static var writingStyle: String {
        get { read("writingStyle") ?? "original" }
        set { write(newValue, key: "writingStyle") }
    }

    static var writingEnabled: Bool {
        get { read("writingEnabled").map { $0 == "true" } ?? (writingStyle != "original") }
        set { write(String(newValue), key: "writingEnabled") }
    }

    static var customWritingPrompt: String {
        get { read("customWritingPrompt") ?? "" }
        set { write(String(newValue.prefix(500)), key: "customWritingPrompt") }
    }

    static func saveOptions(_ options: SpeechSelection, for id: String) {
        guard !isDeleted(id) else { return }
        guard let data = try? JSONEncoder().encode(options), let value = String(data: data, encoding: .utf8) else { return }
        write(value, key: "options." + id, service: "soli.verse.transcriptions")
    }

    static func options(for id: String) -> SpeechSelection? {
        guard !isDeleted(id) else { return nil }
        guard let value = read("options." + id, service: "soli.verse.transcriptions") else { return nil }
        return try? JSONDecoder().decode(SpeechSelection.self, from: Data(value.utf8))
    }

    static func rewriteResult(for id: String) -> TranscriptRewriteResult? {
        guard !isDeleted(id) else { return nil }
        guard let value = read("rewrite." + id, service: "soli.verse.transcriptions") else { return nil }
        return try? JSONDecoder().decode(TranscriptRewriteResult.self, from: Data(value.utf8))
    }

    static func saveRewrite(_ result: TranscriptRewriteResult, for id: String) -> TranscriptRewriteResult {
        guard !isDeleted(id) else { return .original(result.original, style: result.style, fallback: .cancelled) }
        guard let data = try? JSONEncoder().encode(result) else { return result }
        var values = query("rewrite." + id, service: "soli.verse.transcriptions")
        values[kSecValueData as String] = data
        values[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(values as CFDictionary, nil)
        if isDeleted(id) {
            removeProcessingState(for: id)
            return .original(result.original, style: result.style, fallback: .cancelled)
        }
        if let cached = rewriteResult(for: id), cached.original == result.original { return cached }
        return result
    }

    static func isDeleted(_ id: String) -> Bool {
        read("deleted." + id, service: "soli.verse.transcriptions") == "true"
    }

    static func invalidateTranscription(_ id: String) {
        write("true", key: "deleted." + id, service: "soli.verse.transcriptions")
        removeProcessingState(for: id)
    }

    static func removeProcessingState(for id: String) {
        for key in ["options." + id, "rewrite." + id, "claim." + id] {
            SecItemDelete(query(key, service: "soli.verse.transcriptions") as CFDictionary)
        }
    }

    static func claimRewrite(for id: String) -> String? {
        let key = "claim." + id
        if let value = read(key, service: "soli.verse.transcriptions"),
           let lease = try? JSONDecoder().decode(RewriteLease.self, from: Data(value.utf8)),
           Date().timeIntervalSince1970 - lease.started > 20 {
            releaseRewrite(for: id, owner: lease.owner)
        }
        let lease = RewriteLease(owner: UUID().uuidString, started: Date().timeIntervalSince1970)
        guard let data = try? JSONEncoder().encode(lease) else { return nil }
        var values = query(key, service: "soli.verse.transcriptions")
        values[kSecValueData as String] = data
        values[kSecAttrGeneric as String] = Data(lease.owner.utf8)
        values[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(values as CFDictionary, nil) == errSecSuccess ? lease.owner : nil
    }

    static func releaseRewrite(for id: String, owner: String) {
        var values = query("claim." + id, service: "soli.verse.transcriptions")
        values[kSecAttrGeneric as String] = Data(owner.utf8)
        SecItemDelete(values as CFDictionary)
    }

    static var typingKeyboardEnabled: Bool {
        get { read("typingKeyboardEnabled") == "true" }
        set { write(String(newValue), key: "typingKeyboardEnabled") }
    }

    static var keyboardSetupConfirmed: Bool {
        get { read("keyboardSetupConfirmed") == "true" }
        set { write(String(newValue), key: "keyboardSetupConfirmed") }
    }

    static var recordingStartedAt: Double {
        get { Double(read("recordingStartedAt") ?? "0") ?? 0 }
        set { write(String(newValue), key: "recordingStartedAt") }
    }

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
        guard read("pendingJobID") == id, read("deleted." + id, service: "soli.verse.transcriptions") != "true", !Task.isCancelled else { return }
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

    nonisolated private static func query(_ key: String, service: String = "soli.verse.bridge") -> [String: Any] {
        var values: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let group = Bundle.main.object(forInfoDictionaryKey: "VerseKeychainAccessGroup") as? String,
           !group.contains("$(") {
            values[kSecAttrAccessGroup as String] = group
        }
        return values
    }

    nonisolated private static func read(_ key: String, service: String = "soli.verse.bridge") -> String? {
        var values = query(key, service: service)
        values[kSecReturnData as String] = true
        values[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(values as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    nonisolated private static func write(_ value: String, key: String, service: String = "soli.verse.bridge") {
        let values = query(key, service: service)
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(values as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            SecItemAdd(values.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
    }
}
