import Foundation

struct APIStatusHandler {
    static func register(router: WebRouter) {
        router.addRoute(method: "GET", path: "/api/status") { _ in
            let camera = CameraManager.shared
            let automation = AutomationScheduler.shared
            let storage = StorageManager.shared
            let health = HealthMonitor.shared

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.2"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "10"
            let deviceName = camera.activeCameraName.isEmpty ? "Unknown" : camera.activeCameraName

            return HTTPResponse.json([
                "version": version,
                "build": build,
                "camera": [
                    "isRunning": camera.isSessionRunning,
                    "deviceName": deviceName
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
