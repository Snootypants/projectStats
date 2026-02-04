import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.35bird.projectStats"

    private let likelySuffixes: [String] = [
        "_API_KEY",
        "_TOKEN",
        "_SECRET",
        "_SECRET_KEY",
        "_ACCESS_KEY",
        "_ACCESS_KEY_ID",
        "_SECRET_ACCESS_KEY",
        "_AUTH_TOKEN",
        "_ACCOUNT_SID",
        "_WEBHOOK_SECRET",
        "_PRIVATE_KEY",
        "_PUBLIC_KEY",
        "_URL"
    ]

    private let preferredKeys: Set<String> = [
        "OPENAI_API_KEY",
        "ANTHROPIC_API_KEY",
        "GITHUB_TOKEN",
        "GITHUB_PAT",
        "STRIPE_SECRET_KEY",
        "STRIPE_PUBLISHABLE_KEY",
        "DATABASE_URL",
        "AWS_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY",
        "SENDGRID_API_KEY",
        "TWILIO_ACCOUNT_SID",
        "TWILIO_AUTH_TOKEN"
    ]

    private init() {}

    func getSecret(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    func listAvailableKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return []
        }

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        let accounts = items.compactMap { $0[kSecAttrAccount as String] as? String }
        let filtered = accounts.filter { isLikelyEnvKey($0) }
        return Array(Set(filtered)).sorted()
    }

    @discardableResult
    func setSecret(_ value: String, forKey key: String) -> Bool {
        let data = value.data(using: .utf8) ?? Data()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return true
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    private func isLikelyEnvKey(_ key: String) -> Bool {
        if preferredKeys.contains(key) { return true }
        for suffix in likelySuffixes where key.hasSuffix(suffix) {
            return true
        }
        return false
    }

    // MARK: - App-Scoped Keychain (for Settings API Keys)

    /// Save a value to app-scoped keychain
    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    /// Get a value from app-scoped keychain
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Delete a value from app-scoped keychain
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
