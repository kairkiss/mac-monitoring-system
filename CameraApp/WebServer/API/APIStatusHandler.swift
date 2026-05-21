import Foundation

struct APIStatusHandler {
    static func register(router: WebRouter) {
        router.addRoute(method: "GET", path: "/api/status") { _ in
            let camera = CameraManager.shared
            let automation = AutomationScheduler.shared
            let storage = StorageManager.shared
            let health = HealthMonitor.shared

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.1.0"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "11"
            let deviceName = camera.activeCameraName.isEmpty ? "Unknown" : camera.activeCameraName

            let uploadJobs = UploadQueueManager.shared.jobs
            let pending = uploadJobs.filter { $0.status == .pending || $0.status == .retrying }.count
            let active = uploadJobs.filter { $0.status == .uploading }.count
            let failed = uploadJobs.filter { $0.status == .failed }.count
            let completed = uploadJobs.filter { $0.status == .completed }.count

            return HTTPResponse.json([
                "version": version,
                "build": build,
                "camera": [
                    "isRunning": camera.isSessionRunning,
                    "isRecording": camera.isVideoRecording,
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
                    "pending": pending,
                    "active": active,
                    "failed": failed,
                    "completed": completed
                ] as [String: Any]
            ] as [String: Any])
        }
    }
}
