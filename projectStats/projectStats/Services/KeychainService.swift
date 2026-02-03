import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

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

    private func isLikelyEnvKey(_ key: String) -> Bool {
        if preferredKeys.contains(key) { return true }
        for suffix in likelySuffixes where key.hasSuffix(suffix) {
            return true
        }
        return false
    }
}
