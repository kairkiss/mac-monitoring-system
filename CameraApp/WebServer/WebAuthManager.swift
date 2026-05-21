import Foundation
import CryptoKit

enum UserRole: String, Codable {
    case admin
    case operatorRole = "operator"
    case viewer

    func hasPermission(_ required: UserRole) -> Bool {
        switch (self, required) {
        case (.admin, _): return true
        case (.operatorRole, .operatorRole): return true
        case (.operatorRole, .viewer): return true
        case (.viewer, .viewer): return true
        default: return false
        }
    }
}

struct WebUser: Codable {
    let username: String
    let passwordHash: String
    var role: UserRole
    var enabled: Bool

    func verifyPassword(_ password: String) -> Bool {
        let hash = WebAuthManager.hashPassword(password)
        return hash == passwordHash
    }
}

struct WebSession {
    let token: String
    let username: String
    let role: UserRole
    let createdAt: Date
    let expiresAt: Date

    var isValid: Bool { Date() < expiresAt }
}

final class WebAuthManager {
    static let shared = WebAuthManager()

    private var users: [WebUser] = []
    private var sessions: [String: WebSession] = [:]
    private let sessionDuration: TimeInterval = 24 * 3600

    private var usersFileURL: URL {
        MediaLibraryManager.shared.baseDirectory.appendingPathComponent("web_users.json")
    }

    private init() {
        loadUsers()
    }

    // MARK: - Password Hashing

    static func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - User Management

    func loadUsers() {
        guard let data = try? Data(contentsOf: usersFileURL) else {
            // Create default admin user
            createDefaultAdmin()
            return
        }
        users = (try? JSONDecoder().decode([WebUser].self, from: data)) ?? []
        if users.isEmpty {
            createDefaultAdmin()
        }
    }

    private func createDefaultAdmin() {
        let secret = KeychainService.shared.webAuthSecret
        let password: String
        if secret.isEmpty {
            // Generate a random password
            password = String((0..<16).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
            KeychainService.shared.webAuthSecret = password
            ActivityLogManager.shared.warning(.webServer, "Generated new admin password — check Settings")
        } else {
            password = secret
        }

        let admin = WebUser(
            username: "admin",
            passwordHash: WebAuthManager.hashPassword(password),
            role: .admin,
            enabled: true
        )
        users = [admin]
        saveUsers()
    }

    func saveUsers() {
        guard let data = try? JSONEncoder().encode(users) else { return }
        _ = MediaLibraryManager.shared.writeAtomically(data, to: usersFileURL)
    }

    func authenticate(username: String, password: String) -> WebSession? {
        guard let user = users.first(where: { $0.username == username && $0.enabled }),
              user.verifyPassword(password) else {
            return nil
        }

        let token = UUID().uuidString
        let session = WebSession(
            token: token,
            username: user.username,
            role: user.role,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(sessionDuration)
        )
        sessions[token] = session
        return session
    }

    func validateSession(_ token: String) -> WebSession? {
        guard let session = sessions[token], session.isValid else {
            sessions.removeValue(forKey: token)
            return nil
        }
        return session
    }

    func invalidateSession(_ token: String) {
        sessions.removeValue(forKey: token)
    }

    func getUsers() -> [[String: Any]] {
        users.map { user in
            [
                "username": user.username,
                "role": user.role.rawValue,
                "enabled": user.enabled
            ] as [String: Any]
        }
    }

    func addUser(username: String, password: String, role: UserRole) -> Bool {
        guard !users.contains(where: { $0.username == username }) else { return false }
        let user = WebUser(
            username: username,
            passwordHash: WebAuthManager.hashPassword(password),
            role: role,
            enabled: true
        )
        users.append(user)
        saveUsers()
        return true
    }

    func updateUserRole(username: String, role: UserRole) -> Bool {
        guard let index = users.firstIndex(where: { $0.username == username }) else { return false }
        users[index].role = role
        saveUsers()
        return true
    }

    func toggleUser(username: String) -> Bool {
        guard let index = users.firstIndex(where: { $0.username == username }) else { return false }
        users[index].enabled.toggle()
        saveUsers()
        return true
    }

    func changePassword(username: String, newPassword: String) -> Bool {
        guard let index = users.firstIndex(where: { $0.username == username }) else { return false }
        users[index] = WebUser(
            username: users[index].username,
            passwordHash: WebAuthManager.hashPassword(newPassword),
            role: users[index].role,
            enabled: users[index].enabled
        )
        saveUsers()
        return true
    }

    func deleteUser(username: String) -> Bool {
        guard username != "admin" else { return false }
        users.removeAll { $0.username == username }
        saveUsers()
        return true
    }
}
