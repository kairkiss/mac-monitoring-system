import Foundation

struct APIHealthHandler {
    static func register(router: WebRouter) {
        // Health status
        router.addRoute(method: "GET", path: "/api/health") { _ in
            let health = HealthMonitor.shared
            return HTTPResponse.json([
                "isMonitoring": health.isMonitoring,
                "diskFreeMB": health.diskFreeMB,
                "lastFrameReceived": health.lastFrameReceived.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "consecutiveTelegramFailures": health.consecutiveTelegramFailures
            ] as [String: Any])
        }

        // Health alerts
        router.addRoute(method: "GET", path: "/api/health/alerts") { _ in
            let health = HealthMonitor.shared
            let alerts = health.recentAlerts().map { alert -> [String: Any] in
                let typeName: String
                switch alert.type {
                case .lowDisk: typeName = "lowDisk"
                case .cameraDisconnected: typeName = "cameraDisconnected"
                case .telegramFailure: typeName = "telegramFailure"
                case .frameAnomaly: typeName = "frameAnomaly"
                case .webServerError: typeName = "webServerError"
                case .uploadFailure: typeName = "uploadFailure"
                case .storageProviderError: typeName = "storageProviderError"
                }
                return [
                    "type": typeName,
                    "message": alert.message,
                    "timestamp": ISO8601DateFormatter().string(from: alert.timestamp),
                    "isResolved": alert.isResolved
                ] as [String: Any]
            }
            return HTTPResponse.json(["alerts": alerts])
        }
    }
}
