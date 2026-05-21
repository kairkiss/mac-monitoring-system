import Foundation

struct APIStorageHandler {
    static func register(router: WebRouter) {
        // Get storage status
        router.addRoute(method: "GET", path: "/api/storage/status") { _ in
            let manager = StorageManager.shared
            let provider = manager.activeProvider
            let media = MediaLibraryManager.shared
            return HTTPResponse.json([
                "activeProvider": manager.activeProviderType.rawValue,
                "providerDisplayName": provider?.displayName ?? "None",
                "isConfigured": provider?.isConfigured ?? false,
                "totalPhotos": media.totalPhotoCount,
                "totalVideos": media.totalVideoCount,
                "totalStorageBytes": media.totalStorageBytes,
                "diskFreeMB": HealthMonitor.shared.diskFreeMB
            ] as [String: Any])
        }

        // Test storage connection
        router.addRoute(method: "POST", path: "/api/storage/test") { _ in
            let manager = StorageManager.shared
            guard manager.activeProvider != nil else {
                return HTTPResponse.error("No storage provider configured", status: 400)
            }
            let semaphore = DispatchSemaphore(value: 0)
            var result = false
            Task {
                result = await manager.testConnection()
                semaphore.signal()
            }
            semaphore.wait()
            return HTTPResponse.json(["connected": result])
        }

        // List available provider types
        router.addRoute(method: "GET", path: "/api/storage/providers") { _ in
            let providers: [[String: Any]] = StorageProviderType.allCases.map { type in
                [
                    "type": type.rawValue,
                    "displayName": type.displayName,
                    "isAvailable": type == .localFolder || type == .mountedFolder,
                    "isPlanned": type == .googleDrive || type == .webdav
                ] as [String: Any]
            }
            return HTTPResponse.json(["providers": providers])
        }
    }
}
