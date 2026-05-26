import Foundation

struct APIAuthHandler {
    static func register(router: WebRouter) {
        router.addRoute(method: "POST", path: "/api/auth/login", requiresAuth: false) { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let username = json["username"],
                  let password = json["password"] else {
                return HTTPResponse.error("Missing username or password")
            }

            if let session = WebAuthManager.shared.authenticate(username: username, password: password) {
                return HTTPResponse.json([
                    "token": session.token,
                    "username": session.username,
                    "role": session.role.rawValue,
                    "expiresAt": ISO8601DateFormatter().string(from: session.expiresAt)
                ])
            }
            return HTTPResponse.error("Invalid credentials", status: 401)
        }

        router.addRoute(method: "POST", path: "/api/auth/logout") { request in
            if let token = request.bearerToken {
                WebAuthManager.shared.invalidateSession(token)
            }
            return HTTPResponse.ok()
        }

        router.addRoute(method: "GET", path: "/api/auth/me") { request in
            guard let token = request.bearerToken,
                  let session = WebAuthManager.shared.validateSession(token) else {
                return HTTPResponse.error("Unauthorized", status: 401)
            }
            return HTTPResponse.json([
                "username": session.username,
                "role": session.role.rawValue
            ])
        }

        // User management (admin only)
        router.addRoute(method: "GET", path: "/api/auth/users", requiredRole: .admin) { _ in
            let users = WebAuthManager.shared.getUsers()
            return HTTPResponse.json(["users": users])
        }

        router.addRoute(method: "POST", path: "/api/auth/users", requiredRole: .admin) { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let username = json["username"] as? String,
                  let password = json["password"] as? String,
                  let roleStr = json["role"] as? String,
                  let role = UserRole(rawValue: roleStr) else {
                return HTTPResponse.error("Missing required fields")
            }

            if WebAuthManager.shared.addUser(username: username, password: password, role: role) {
                AuditLogManager.shared.log(
                    method: "POST", path: "/api/auth/users", status: 200,
                    remoteAddress: request.remoteAddress ?? "unknown",
                    user: request.sessionUsername,
                    detail: "create user: \(username)"
                )
                return HTTPResponse.json(["status": "created"], status: 201)
            }
            return HTTPResponse.error("User already exists", status: 409)
        }

        router.addRoute(method: "PUT", path: "/api/auth/users/:username/role", requiredRole: .admin) { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let roleStr = json["role"],
                  let role = UserRole(rawValue: roleStr) else {
                return HTTPResponse.error("Missing role")
            }

            let username = router.extractParam("username", from: request, pattern: "/api/auth/users/:username/role") ?? ""
            if WebAuthManager.shared.updateUserRole(username: username, role: role) {
                AuditLogManager.shared.log(
                    method: "PUT", path: "/api/auth/users/:username/role", status: 200,
                    remoteAddress: request.remoteAddress ?? "unknown",
                    user: request.sessionUsername,
                    detail: "change role: \(username) → \(role.rawValue)"
                )
                return HTTPResponse.ok()
            }
            return HTTPResponse.error("User not found", status: 404)
        }

        router.addRoute(method: "PUT", path: "/api/auth/users/:username/password", requiredRole: .admin) { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let newPassword = json["newPassword"] else {
                return HTTPResponse.error("Missing newPassword")
            }

            let username = router.extractParam("username", from: request, pattern: "/api/auth/users/:username/password") ?? ""
            if WebAuthManager.shared.changePassword(username: username, newPassword: newPassword) {
                AuditLogManager.shared.log(
                    method: "PUT", path: "/api/auth/users/:username/password", status: 200,
                    remoteAddress: request.remoteAddress ?? "unknown",
                    user: request.sessionUsername,
                    detail: "reset password: \(username)"
                )
                return HTTPResponse.ok()
            }
            return HTTPResponse.error("User not found", status: 404)
        }

        router.addRoute(method: "DELETE", path: "/api/auth/users/:username", requiredRole: .admin) { request in
            let username = router.extractParam("username", from: request, pattern: "/api/auth/users/:username") ?? ""
            if WebAuthManager.shared.deleteUser(username: username) {
                AuditLogManager.shared.log(
                    method: "DELETE", path: "/api/auth/users/:username", status: 200,
                    remoteAddress: request.remoteAddress ?? "unknown",
                    user: request.sessionUsername,
                    detail: "delete user: \(username)"
                )
                return HTTPResponse.ok()
            }
            return HTTPResponse.error("Cannot delete user", status: 400)
        }

        // Change current user's password (any authenticated user)
        router.addRoute(method: "POST", path: "/api/auth/change-password") { request in
            guard let token = request.bearerToken,
                  let session = WebAuthManager.shared.validateSession(token) else {
                return HTTPResponse.error("Unauthorized", status: 401)
            }
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let currentPwd = json["currentPassword"],
                  let newPwd = json["newPassword"] else {
                return HTTPResponse.error("Missing currentPassword or newPassword")
            }
            guard newPwd.count >= 8 else {
                return HTTPResponse.error("Password must be at least 8 characters", status: 400)
            }
            // Verify current password
            guard let userSession = WebAuthManager.shared.authenticate(username: session.username, password: currentPwd) else {
                return HTTPResponse.error("Current password is incorrect", status: 403)
            }
            if WebAuthManager.shared.changePassword(username: session.username, newPassword: newPwd) {
                // If admin, also update Keychain
                if session.role == .admin {
                    KeychainService.shared.webAuthSecret = newPwd
                }
                WebAuthManager.shared.invalidateAllSessions()
                ActivityLogManager.shared.info(.webServer, "Password changed for user: \(session.username)")
                return HTTPResponse.json(["status": "ok", "message": "Password changed. Please log in again."])
            }
            return HTTPResponse.error("Failed to change password", status: 500)
        }

        // Change admin username (admin only)
        router.addRoute(method: "POST", path: "/api/auth/change-username", requiredRole: .admin) { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let newUsername = json["newUsername"] else {
                return HTTPResponse.error("Missing newUsername")
            }
            let currentUsername = WebAuthManager.shared.currentAdminUsername()
            guard WebAuthManager.shared.validateUsername(newUsername) else {
                return HTTPResponse.error("Invalid username: 3-32 chars, letters/numbers/_/- only", status: 400)
            }
            if WebAuthManager.shared.changeAdminUsername(from: currentUsername, to: newUsername) {
                ActivityLogManager.shared.info(.webServer, "Admin username changed to: \(newUsername)")
                return HTTPResponse.json(["status": "ok", "message": "Username changed. Please log in again."])
            }
            return HTTPResponse.error("Failed to change username", status: 400)
        }
    }
}
