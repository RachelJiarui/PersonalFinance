import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private init() {}

    enum KeychainError: Error {
        case duplicateItem
        case itemNotFound
        case invalidData
        case unhandledError(status: OSStatus)
    }

    func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(key: key, data: data)
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }

    func load(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw status == errSecItemNotFound ? KeychainError.itemNotFound : KeychainError.unhandledError(status: status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    private func update(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

extension KeychainService {
    func saveAccessToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(key: "plaid_access_token", data: data)
    }

    func loadAccessToken() throws -> String {
        let data = try load(key: "plaid_access_token")
        guard let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return token
    }

    func deleteAccessToken() throws {
        try delete(key: "plaid_access_token")
    }

    func hasAccessToken() -> Bool {
        do {
            _ = try loadAccessToken()
            return true
        } catch {
            return false
        }
    }
}
