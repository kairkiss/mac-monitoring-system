import Foundation

struct APIStorageHandler {
    static func register(router: WebRouter) {
        // Get storage status
        router.addRoute(method: "GET", path: "/api/storage/status") { _ in
            let manager = StorageManager.shared
            let provider = manager.activeProvider
            let media = MediaLibraryManager.shared
            let gdAuth = GoogleDriveAuthManager.shared
            let settings = SettingsStore.shared
            let webServer = WebServerManager.shared

            var result: [String: Any] = [
                "activeProvider": manager.activeProviderType.rawValue,
                "providerDisplayName": provider?.displayName ?? "None",
                "isConfigured": provider?.isConfigured ?? false,
                "totalPhotos": media.totalPhotoCount,
                "totalVideos": media.totalVideoCount,
                "totalStorageBytes": media.totalStorageBytes,
                "diskFreeMB": HealthMonitor.shared.diskFreeMB,
                "webServerRunning": webServer.isRunning,
                "webServerLocalURL": "http://\(settings.webServerBindAddress):\(settings.webServerPort)"
            ]

            // Google Drive specific
            if manager.activeProviderType == .googleDrive {
                result["googleDriveConnected"] = gdAuth.isAuthenticated
                result["googleDriveEmail"] = gdAuth.userEmail
                result["googleDriveNeedsReconnect"] = gdAuth.needsReconnect
                result["rootFolderName"] = settings.googleDriveRootFolderName.isEmpty ? "MacMonitor" : settings.googleDriveRootFolderName
            }

            // WebDAV status
            result["webdavStatus"] = "planned"

            return HTTPResponse.json(result)
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
            let activeType = StorageManager.shared.activeProviderType
            let gdAuth = GoogleDriveAuthManager.shared
            let providers: [[String: Any]] = StorageProviderType.allCases.compactMap { type in
                guard type != .none else { return nil }
                var isAvailable = false
                var isPlanned = false
                var detail = ""

                switch type {
                case .localFolder, .mountedFolder:
                    isAvailable = true
                case .googleDrive:
                    isAvailable = gdAuth.isAuthenticated
                    detail = gdAuth.isAuthenticated ? gdAuth.userEmail : "Not signed in"
                case .webdav:
                    isPlanned = true
                    detail = "Planned — not yet implemented"
                default:
                    break
                }

                return [
                    "type": type.rawValue,
                    "displayName": type.displayName,
                    "isAvailable": isAvailable,
                    "isPlanned": isPlanned,
                    "isActive": type == activeType,
                    "detail": detail
                ] as [String: Any]
            }
            return HTTPResponse.json(["providers": providers])
        }
    }
}
