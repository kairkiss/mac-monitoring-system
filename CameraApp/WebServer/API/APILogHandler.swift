import Foundation

struct APILogHandler {
    static func register(router: WebRouter) {
        // List logs
        router.addRoute(method: "GET", path: "/api/logs") { request in
            let limit = Int(request.queryParameters["limit"] ?? "100") ?? 100
            let category = request.queryParameters["category"]
            let search = request.queryParameters["search"]

            let entries = ActivityLogManager.shared.entries(limit: limit)

            var filtered = entries
            if let category = category {
                filtered = filtered.filter { $0.category.rawValue == category }
            }
            if let search = search, !search.isEmpty {
                filtered = filtered.filter { $0.message.localizedCaseInsensitiveContains(search) }
            }

            let items = filtered.map { entry in
                [
                    "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                    "level": entry.level.rawValue,
                    "category": entry.category.rawValue,
                    "message": entry.message,
                    "detail": entry.detail ?? ""
                ] as [String: Any]
            }

            return HTTPResponse.json(["logs": items, "total": items.count])
        }

        // Export logs
        router.addRoute(method: "GET", path: "/api/logs/export") { _ in
            let url = ActivityLogManager.shared.logFileURL
            guard let data = try? Data(contentsOf: url) else {
                return HTTPResponse.error("No log file", status: 404)
            }
            return HTTPResponse(
                status: 200,
                statusText: "OK",
                headers: [
                    "Content-Type": "application/jsonl",
                    "Content-Disposition": "attachment; filename=\"activity_log.jsonl\""
                ],
                body: data
            )
        }

        // Clear logs
        router.addRoute(method: "DELETE", path: "/api/logs", requiredRole: .admin) { _ in
            ActivityLogManager.shared.clearLog()
            return HTTPResponse.ok()
        }

        // Read audit log (admin only)
        router.addRoute(method: "GET", path: "/api/audit", requiredRole: .admin) { request in
            let limit = Int(request.queryParameters["limit"] ?? "100") ?? 100
            let entries = AuditLogManager.shared.readEntries(limit: limit)
            let items = entries.map { entry -> [String: Any] in
                [
                    "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                    "method": entry.method,
                    "path": entry.path,
                    "status": entry.status,
                    "duration": Int(entry.duration * 1000),
                    "remoteAddress": entry.remoteAddress,
                    "user": entry.user ?? ""
                ] as [String: Any]
            }
            return HTTPResponse.json(["entries": items, "total": items.count])
        }

        // Clear audit log (admin only)
        router.addRoute(method: "DELETE", path: "/api/audit", requiredRole: .admin) { _ in
            AuditLogManager.shared.clear()
            return HTTPResponse.ok()
        }
    }
}
