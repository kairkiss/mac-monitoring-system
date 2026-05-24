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

            // Upload queue summary
            let queue = UploadQueueManager.shared
            result["uploadPending"] = queue.jobs.filter { $0.status == .pending }.count
            result["uploadWaiting"] = queue.jobs.filter { $0.status == .waitingForProvider }.count
            result["uploadFailed"] = queue.jobs.filter { $0.status == .failed }.count

            // WebDAV status
            result["webdavStatus"] = "planned"

            return HTTPResponse.json(result)
        }

        // Test storage connection (enriched with diagnostics)
        router.addRoute(method: "POST", path: "/api/storage/test") { _ in
            let manager = StorageManager.shared
            guard manager.activeProvider != nil else {
                return HTTPResponse.error("No storage provider configured", status: 400)
            }
            let semaphore = DispatchSemaphore(value: 0)
            var diag: StorageDiagnostics?
            Task {
                diag = await manager.testConnectionDetailed()
                semaphore.signal()
            }
            semaphore.wait()
            guard let d = diag else {
                return HTTPResponse.json(["connected": false, "error": "Test unavailable"] as [String: Any])
            }
            var resp: [String: Any] = [
                "connected": d.isConnected,
                "lastTestSuccess": d.lastTestSuccess
            ]
            if let email = d.authenticatedEmail { resp["email"] = email }
            if let error = d.lastTestError { resp["error"] = error }
            if let errorClass = d.lastTestErrorClass { resp["errorClass"] = errorClass.rawValue }
            if let used = d.quotaUsedGB { resp["quotaUsedGB"] = round(used * 10) / 10 }
            if let total = d.quotaTotalGB { resp["quotaTotalGB"] = round(total * 10) / 10 }
            return HTTPResponse.json(resp)
        }

        // Storage diagnostics
        router.addRoute(method: "GET", path: "/api/storage/diagnostics") { _ in
            let manager = StorageManager.shared
            let semaphore = DispatchSemaphore(value: 0)
            var diag: StorageDiagnostics?
            Task {
                diag = await manager.testConnectionDetailed()
                semaphore.signal()
            }
            semaphore.wait()
            guard let d = diag else {
                return HTTPResponse.error("Diagnostics unavailable", status: 500)
            }
            var result: [String: Any] = [
                "providerType": d.providerType,
                "isConnected": d.isConnected,
                "lastTestDate": ISO8601DateFormatter().string(from: d.lastTestDate ?? Date()),
                "lastTestSuccess": d.lastTestSuccess,
                "recentUploadCount": d.recentUploadCount,
                "recentFailureCount": d.recentFailureCount
            ]
            if let email = d.authenticatedEmail { result["authenticatedEmail"] = email }
            if let error = d.lastTestError { result["lastTestError"] = error }
            if let errorClass = d.lastTestErrorClass { result["lastTestErrorClass"] = errorClass.rawValue }
            if let folderName = d.rootFolderName { result["rootFolderName"] = folderName }
            if let exists = d.rootFolderExists { result["rootFolderExists"] = exists }
            if let used = d.quotaUsedGB { result["quotaUsedGB"] = round(used * 10) / 10 }
            if let total = d.quotaTotalGB { result["quotaTotalGB"] = round(total * 10) / 10 }
            return HTTPResponse.json(result)
        }

        // Retention dry run
        router.addRoute(method: "POST", path: "/api/storage/retention/dry-run") { _ in
            let result = RetentionManager.shared.dryRun()
            return HTTPResponse.json([
                "wouldDelete": result.wouldDelete,
                "skipped": result.skipped,
                "files": Array(result.files.prefix(50)),
                "reason": result.reason ?? ""
            ] as [String: Any])
        }

        // Cloudflared detection
        router.addRoute(method: "GET", path: "/api/storage/cloudflared") { _ in
            let fm = FileManager.default
            let paths = ["/opt/homebrew/bin/cloudflared", "/usr/local/bin/cloudflared", "/usr/bin/cloudflared"]
            var detected = false
            var detectedPath = ""
            for path in paths {
                if fm.fileExists(atPath: path) {
                    detected = true
                    detectedPath = path
                    break
                }
            }
            return HTTPResponse.json([
                "detected": detected,
                "path": detectedPath
            ] as [String: Any])
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
