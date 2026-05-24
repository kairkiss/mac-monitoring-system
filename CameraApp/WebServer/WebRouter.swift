import Foundation

typealias RouteHandler = (HTTPRequest) -> HTTPResponse

struct Route {
    let method: String
    let pattern: String
    let handler: RouteHandler
    let requiresAuth: Bool
    let requiredRole: UserRole?
}

final class WebRouter {
    private var routes: [Route] = []
    private var staticFileRoot: URL?

    func addRoute(method: String, path: String, requiresAuth: Bool = true, requiredRole: UserRole? = nil, handler: @escaping RouteHandler) {
        // Prevent duplicate routes on restart
        guard !routes.contains(where: { $0.method == method && $0.pattern == path }) else { return }
        routes.append(Route(method: method, pattern: path, handler: handler, requiresAuth: requiresAuth, requiredRole: requiredRole))
    }

    func setStaticFileRoot(_ url: URL) {
        staticFileRoot = url
    }

    func handle(request: HTTPRequest) -> HTTPResponse {
        // Check for exact match first
        for route in routes {
            if route.method == request.method && matchPattern(route.pattern, against: request.path) {
                var req = request
                if route.requiresAuth {
                    guard let token = request.bearerToken,
                          let session = WebAuthManager.shared.validateSession(token) else {
                        return HTTPResponse.error("Unauthorized", status: 401)
                    }
                    req.sessionUsername = session.username
                    req.sessionRole = session.role
                    if let requiredRole = route.requiredRole {
                        guard session.role.hasPermission(requiredRole) else {
                            ActivityLogManager.shared.warning(.security, "Permission denied: \(session.username) (\(session.role.rawValue)) attempted \(request.method) \(request.path)")
                            return HTTPResponse.error("Forbidden", status: 403)
                        }
                    }
                }
                return route.handler(req)
            }
        }

        // Try static files
        if request.method == "GET" && !request.path.hasPrefix("/api/") {
            return serveStaticFile(path: request.path)
        }

        return HTTPResponse.error("Not Found", status: 404)
    }

    private func matchPattern(_ pattern: String, against path: String) -> Bool {
        // Exact match
        if pattern == path { return true }

        // Pattern with wildcards: /api/media/:id/thumbnail
        let patternParts = pattern.split(separator: "/")
        let pathParts = path.split(separator: "/")

        guard patternParts.count == pathParts.count else { return false }

        for (p, t) in zip(patternParts, pathParts) {
            if p.hasPrefix(":") { continue } // Wildcard segment
            if p != t { return false }
        }
        return true
    }

    func extractParam(_ name: String, from request: HTTPRequest, pattern: String) -> String? {
        let patternParts = pattern.split(separator: "/")
        let pathParts = request.path.split(separator: "/")

        guard patternParts.count == pathParts.count else { return nil }

        for (p, v) in zip(patternParts, pathParts) {
            if p == ":\(name)" {
                return String(v)
            }
        }
        return nil
    }

    private func serveStaticFile(path: String) -> HTTPResponse {
        guard let root = staticFileRoot else {
            return HTTPResponse.error("Static files not configured", status: 404)
        }

        var filePath = path
        if filePath == "/" { filePath = "/index.html" }

        // Security: prevent directory traversal
        let sanitized = filePath.replacingOccurrences(of: "..", with: "")
        let url = root.appendingPathComponent(sanitized)

        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return HTTPResponse.error("Not Found", status: 404)
        }

        let contentType = mimeType(for: url.pathExtension)
        return HTTPResponse.data(data, contentType: contentType)
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "js": return "application/javascript; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "ttf": return "font/ttf"
        default: return "application/octet-stream"
        }
    }
}
