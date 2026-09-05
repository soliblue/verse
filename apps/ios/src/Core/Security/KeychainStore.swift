import Foundation
import Security

enum KeychainStore {
    private static let service = "soli.verse"

    static func value(for account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess
            ? (result as? Data).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            : ""
    }

}
