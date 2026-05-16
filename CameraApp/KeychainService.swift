import Foundation
import Security

enum KeychainError: LocalizedError {
    case duplicateItem
    case notFound
    case unexpectedStatus(OSStatus)
    case dataCorrupted

    var errorDescription: String? {
        switch self {
        case .duplicateItem: return "Keychain item already exists"
        case .notFound: return "Keychain item not found"
        case .unexpectedStatus(let status): return "Keychain error: status \(status)"
        case .dataCorrupted: return "Keychain data corrupted"
        }
    }
}

final class KeychainService {
    static let shared = KeychainService()

    let service = "com.kairkiss.MacMonitor"
    let tokenAccount = "telegramBotToken"

    private init() {}

    func save(_ value: String, service: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataCorrupted
        }

        // Delete existing item first
        try? delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func read(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataCorrupted
        }

        return string
    }

    func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Token Migration

    func migrateTokenIfNeeded() {
        let ud = UserDefaults.standard
        guard let oldToken = ud.string(forKey: "telegramBotToken"), !oldToken.isEmpty else { return }

        do {
            // Check if keychain already has a token
            let existing = try read(service: service, account: tokenAccount)
            if existing == nil || existing?.isEmpty == true {
                try save(oldToken, service: service, account: tokenAccount)
            }
            // Remove from UserDefaults
            ud.removeObject(forKey: "telegramBotToken")
            ActivityLogManager.shared.success(.security, "Bot Token migrated to Keychain")
        } catch {
            ActivityLogManager.shared.error(.security, "Keychain migration failed", detail: error.localizedDescription)
        }
    }

    // MARK: - Token Access

    var telegramBotToken: String {
        get {
            (try? read(service: service, account: tokenAccount)) ?? ""
        }
        set {
            if newValue.isEmpty {
                try? delete(service: service, account: tokenAccount)
            } else {
                do {
                    try save(newValue, service: service, account: tokenAccount)
                } catch {
                    ActivityLogManager.shared.error(.security, "Failed to save token to Keychain", detail: error.localizedDescription)
                }
            }
        }
    }
}
