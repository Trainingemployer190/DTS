import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    // MARK: - Save Data
    func save(data: Data, for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func save(string: String, for key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data: data, for: key)
    }

    // MARK: - Retrieve Data
    func getData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        return status == errSecSuccess ? result as? Data : nil
    }

    func getString(for key: String) -> String? {
        guard let data = getData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete Data
    func delete(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }

    // MARK: - Token Management
    func saveAccessToken(_ token: String) -> Bool {
        return save(string: token, for: "access_token")
    }

    func getAccessToken() -> String? {
        return getString(for: "access_token")
    }

    func saveRefreshToken(_ token: String) -> Bool {
        return save(string: token, for: "refresh_token")
    }

    func getRefreshToken() -> String? {
        return getString(for: "refresh_token")
    }

    func clearAllTokens() -> Bool {
        let accessDeleted = delete(for: "access_token")
        let refreshDeleted = delete(for: "refresh_token")
        return accessDeleted && refreshDeleted
    }
}

// MARK: - Direct Keychain Access (for compatibility with working version)
class Keychain {
    static func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        return status == errSecSuccess ? result as? Data : nil
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
