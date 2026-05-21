import Foundation

struct APIStatusHandler {
    static func register(router: WebRouter) {
        router.addRoute(method: "GET", path: "/api/status") { _ in
            let camera = CameraManager.shared
            let automation = AutomationScheduler.shared
            let storage = StorageManager.shared
            let health = HealthMonitor.shared

            return HTTPResponse.json([
                "version": "2.0.0",
                "build": 8,
                "camera": [
                    "isRunning": camera.isSessionRunning,
                    "deviceName": camera.activeCameraName ?? "None"
                ] as [String: Any],
                "automation": [
                    "isEnabled": automation.isAutomationEnabled,
                    "taskCount": automation.tasks.count
                ] as [String: Any],
                "storage": [
                    "provider": storage.activeProviderType.rawValue
                ] as [String: Any],
                "health": [
                    "isMonitoring": health.isMonitoring
                ] as [String: Any],
                "uploadQueue": [
                    "pending": MediaIndexStore.shared.pendingUploadItems().count
                ] as [String: Any]
            ] as [String: Any])
        }
    }
}
