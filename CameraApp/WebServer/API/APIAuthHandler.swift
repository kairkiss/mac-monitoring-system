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
                return HTTPResponse.ok()
            }
            return HTTPResponse.error("User not found", status: 404)
        }

        router.addRoute(method: "DELETE", path: "/api/auth/users/:username", requiredRole: .admin) { request in
            let username = router.extractParam("username", from: request, pattern: "/api/auth/users/:username") ?? ""
            if WebAuthManager.shared.deleteUser(username: username) {
                return HTTPResponse.ok()
            }
            return HTTPResponse.error("Cannot delete user", status: 400)
        }
    }
}
