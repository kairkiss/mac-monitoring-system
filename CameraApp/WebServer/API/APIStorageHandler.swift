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
                // Connection state
                let hasCreds = !settings.googleDriveClientID.isEmpty && !KeychainService.shared.googleDriveClientSecret.isEmpty
                if !hasCreds {
                    result["googleDriveConnectionState"] = "credentialsMissing"
                } else if !gdAuth.isAuthenticated && gdAuth.needsReconnect {
                    result["googleDriveConnectionState"] = "needsReconnect"
                } else if !gdAuth.isAuthenticated {
                    result["googleDriveConnectionState"] = "notAuthenticated"
                } else {
                    result["googleDriveConnectionState"] = "connected"
                }
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
        router.addRoute(method: "POST", path: "/api/storage/test", requiredRole: .operatorRole) { _ in
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

        // Test storage connection (compat alias for /api/storage/test)
        router.addRoute(method: "POST", path: "/api/storage/test-connection", requiredRole: .operatorRole) { request in
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
        router.addRoute(method: "POST", path: "/api/storage/retention/dry-run", requiredRole: .admin) { _ in
            let result = RetentionManager.shared.dryRun()
            return HTTPResponse.json([
                "wouldDelete": result.wouldDelete,
                "skipped": result.skipped,
                "files": Array(result.files.prefix(50)),
                "reason": result.reason ?? "",
                // Compat fields for legacy frontends
                "deletedFilesCount": result.wouldDelete,
                "freedBytes": 0,
                "details": Array(result.files.prefix(50))
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

                let isActive = type == activeType
                return [
                    "type": type.rawValue,
                    "displayName": type.displayName,
                    "isAvailable": isAvailable,
                    "isPlanned": isPlanned,
                    "isActive": isActive,
                    "detail": detail,
                    // Compat fields for legacy frontends
                    "isCurrent": isActive,
                    "isConnected": isAvailable && !isPlanned,
                    "email": detail,
                    "needsReconnect": false
                ] as [String: Any]
            }
            return HTTPResponse.json(["providers": providers])
        }

        // MARK: - Google Drive Specific Endpoints

        // Google Drive status (detailed connection state)
        router.addRoute(method: "GET", path: "/api/storage/google-drive/status") { _ in
            let gdAuth = GoogleDriveAuthManager.shared
            let settings = SettingsStore.shared
            let queue = UploadQueueManager.shared

            // Determine connection state
            let hasCredentials = !settings.googleDriveClientID.isEmpty && !KeychainService.shared.googleDriveClientSecret.isEmpty
            let connectionState: String
            if !hasCredentials {
                connectionState = "credentialsMissing"
            } else if !gdAuth.isAuthenticated && gdAuth.needsReconnect {
                connectionState = "needsReconnect"
            } else if !gdAuth.isAuthenticated {
                connectionState = "notAuthenticated"
            } else {
                connectionState = "connected"
            }

            // Upload queue stats for Google Drive
            let waitingJobs = queue.jobs.filter { $0.status == .waitingForProvider && $0.providerType == StorageProviderType.googleDrive.rawValue }
            let failedJobs = queue.jobs.filter { $0.status == .failed && $0.providerType == StorageProviderType.googleDrive.rawValue }
            let pendingJobs = queue.jobs.filter { ($0.status == .pending || $0.status == .retrying) && $0.providerType == StorageProviderType.googleDrive.rawValue }

            var result: [String: Any] = [
                "connectionState": connectionState,
                "isAuthenticated": gdAuth.isAuthenticated,
                "needsReconnect": gdAuth.needsReconnect,
                "email": gdAuth.userEmail,
                "hasCredentials": hasCredentials,
                "rootFolderName": settings.googleDriveRootFolderName.isEmpty ? "MacMonitor" : settings.googleDriveRootFolderName,
                "waitingUploads": waitingJobs.count,
                "failedUploads": failedJobs.count,
                "pendingUploads": pendingJobs.count,
                "isCurrentProvider": StorageManager.shared.activeProviderType == .googleDrive
            ]

            // Add quota info if authenticated
            if gdAuth.isAuthenticated {
                let semaphore = DispatchSemaphore(value: 0)
                var diag: StorageDiagnostics?
                Task {
                    diag = await GoogleDriveProvider().testConnectionDetailed()
                    semaphore.signal()
                }
                semaphore.wait()
                if let d = diag {
                    if let used = d.quotaUsedGB { result["quotaUsedGB"] = round(used * 10) / 10 }
                    if let total = d.quotaTotalGB { result["quotaTotalGB"] = round(total * 10) / 10 }
                    if let errClass = d.lastTestErrorClass { result["errorClass"] = errClass.rawValue }
                    if let err = d.lastTestError { result["lastTestError"] = err }
                }
            }

            return HTTPResponse.json(result)
        }

        // Google Drive test connection (dedicated endpoint)
        router.addRoute(method: "POST", path: "/api/storage/google-drive/test", requiredRole: .operatorRole) { _ in
            let provider = GoogleDriveProvider()
            let semaphore = DispatchSemaphore(value: 0)
            var diag: StorageDiagnostics?
            Task {
                diag = await provider.testConnectionDetailed()
                semaphore.signal()
            }
            semaphore.wait()
            guard let d = diag else {
                return HTTPResponse.json(["connected": false, "error": "Test unavailable"] as [String: Any])
            }
            var resp: [String: Any] = [
                "connected": d.isConnected,
                "connectionState": d.connectionState?.rawValue ?? "unknown",
                "lastTestSuccess": d.lastTestSuccess
            ]
            if let email = d.authenticatedEmail { resp["email"] = email }
            if let error = d.lastTestError { resp["error"] = error }
            if let errorClass = d.lastTestErrorClass {
                resp["errorClass"] = errorClass.rawValue
                resp["errorDescription"] = errorClass.localizedDescription
                resp["nextAction"] = errorClass.nextAction
                resp["isRetryable"] = errorClass.isRetryable
            }
            if let used = d.quotaUsedGB { resp["quotaUsedGB"] = round(used * 10) / 10 }
            if let total = d.quotaTotalGB { resp["quotaTotalGB"] = round(total * 10) / 10 }
            if let folderName = d.rootFolderName { resp["rootFolderName"] = folderName }
            return HTTPResponse.json(resp)
        }

        // Google Drive reconnect (re-trigger OAuth)
        router.addRoute(method: "POST", path: "/api/storage/google-drive/reconnect", requiredRole: .operatorRole) { request in
            let settings = SettingsStore.shared
            let clientID = settings.googleDriveClientID
            let clientSecret = KeychainService.shared.googleDriveClientSecret
            guard !clientID.isEmpty, !clientSecret.isEmpty else {
                return HTTPResponse.error("Google Drive credentials not configured", status: 400)
            }
            let user = request.sessionUsername ?? "unknown"
            ActivityLogManager.shared.info(.upload, "Google Drive reconnect requested by \(user)")
            AuditLogManager.shared.log(method: "POST", path: "/api/storage/google-drive/reconnect", status: 200, remoteAddress: request.remoteAddress ?? "unknown", user: request.sessionUsername, detail: "reconnect")
            // Trigger OAuth flow asynchronously
            Task {
                try? await GoogleDriveAuthManager.shared.authenticate(clientID: clientID, clientSecret: clientSecret)
                StorageManager.shared.configure()
            }
            return HTTPResponse.json(["ok": true, "message": "OAuth flow initiated — check your browser"] as [String: Any])
        }

        // Google Drive sign-out (admin-only, clears tokens)
        router.addRoute(method: "POST", path: "/api/storage/google-drive/sign-out", requiredRole: .admin) { request in
            let user = request.sessionUsername ?? "unknown"
            GoogleDriveAuthManager.shared.signOut()
            StorageManager.shared.configure()
            ActivityLogManager.shared.info(.upload, "Google Drive sign-out by \(user)")
            AuditLogManager.shared.log(method: "POST", path: "/api/storage/google-drive/sign-out", status: 200, remoteAddress: request.remoteAddress ?? "unknown", user: request.sessionUsername, detail: "sign-out")
            return HTTPResponse.json(["ok": true] as [String: Any])
        }

        // Google Drive retry waiting uploads (operator+)
        router.addRoute(method: "POST", path: "/api/storage/google-drive/retry-waiting", requiredRole: .operatorRole) { request in
            let queue = UploadQueueManager.shared
            let hasProvider = StorageManager.shared.activeProvider != nil
            var reactivated = 0
            for var job in queue.jobs where job.status == .waitingForProvider {
                if hasProvider {
                    job.status = .pending
                    job.lastError = nil
                    job.errorClass = nil
                    UploadQueueStore.shared.updateJob(job)
                    reactivated += 1
                }
            }
            if hasProvider && reactivated > 0 {
                queue.startProcessing()
            }
            let user = request.sessionUsername ?? "unknown"
            ActivityLogManager.shared.info(.upload, "Retry waiting uploads by \(user): \(reactivated) jobs reactivated")
            AuditLogManager.shared.log(method: "POST", path: "/api/storage/google-drive/retry-waiting", status: 200, remoteAddress: request.remoteAddress ?? "unknown", user: request.sessionUsername, detail: "reactivated \(reactivated) jobs")
            return HTTPResponse.json(["ok": true, "reactivated": reactivated] as [String: Any])
        }

        // Google Drive root folder info
        router.addRoute(method: "GET", path: "/api/storage/google-drive/root") { _ in
            let settings = SettingsStore.shared
            let kc = KeychainService.shared
            let rootName = settings.googleDriveRootFolderName.isEmpty ? "MacMonitor" : settings.googleDriveRootFolderName
            let rootFolderID = kc.googleDriveRootFolderID
            let folderID = settings.googleDriveFolderID
            return HTTPResponse.json([
                "rootFolderName": rootName,
                "rootFolderID": rootFolderID.isEmpty ? "(not cached)" : rootFolderID,
                "folderID": folderID.isEmpty ? "(not set)" : folderID,
                "isAuthenticated": GoogleDriveAuthManager.shared.isAuthenticated
            ] as [String: Any])
        }

        // MARK: - Cloudflare Tunnel

        // Get tunnel status
        router.addRoute(method: "GET", path: "/api/remote/status") { _ in
            let tunnel = CloudflareTunnelManager.shared
            let settings = SettingsStore.shared
            let detection = tunnel.detectCloudflared()

            var result: [String: Any] = [
                "status": tunnel.status.rawValue,
                "tunnelMode": settings.cloudflareTunnelMode.rawValue,
                "tunnelName": settings.cloudflareTunnelName,
                "hostname": settings.cloudflareHostname,
                "cloudflaredDetected": detection.detected,
                "isRunning": tunnel.isRunning
            ]
            if let pid = tunnel.pid { result["pid"] = pid }
            if let path = detection.path { result["cloudflaredPath"] = path }
            if let version = detection.version { result["cloudflaredVersion"] = version }
            if !tunnel.quickTunnelURL.isEmpty { result["quickTunnelURL"] = tunnel.quickTunnelURL }
            if !tunnel.lastError.isEmpty { result["lastError"] = tunnel.lastError }
            if !tunnel.lastOutput.isEmpty {
                let lines = tunnel.lastOutput.components(separatedBy: "\n")
                result["lastOutput"] = lines.suffix(20).joined(separator: "\n")
            }
            return HTTPResponse.json(result)
        }

        // Start tunnel
        router.addRoute(method: "POST", path: "/api/remote/start", requiredRole: .admin) { request in
            let tunnel = CloudflareTunnelManager.shared
            guard !tunnel.isRunning else {
                return HTTPResponse.json(["ok": true, "status": "already_running"] as [String: Any])
            }

            // Parse optional mode from body
            var mode: TunnelMode? = nil
            if let body = request.body,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let modeRaw = json["mode"] as? String {
                mode = TunnelMode(rawValue: modeRaw)
            }

            let effectiveMode = mode ?? SettingsStore.shared.cloudflareTunnelMode
            if effectiveMode == .named && SettingsStore.shared.cloudflareTunnelName.isEmpty {
                return HTTPResponse.error("Tunnel name not configured for named mode", status: 400)
            }

            tunnel.startTunnel(mode: effectiveMode)
            let user = request.sessionUsername ?? "unknown"
            ActivityLogManager.shared.info(.webServer, "Tunnel start requested by \(user): mode=\(effectiveMode.rawValue)")
            AuditLogManager.shared.log(method: "POST", path: "/api/remote/start", status: 200, remoteAddress: request.remoteAddress ?? "unknown", user: request.sessionUsername, detail: "mode=\(effectiveMode.rawValue)")
            return HTTPResponse.json(["ok": true, "status": tunnel.status.rawValue, "mode": effectiveMode.rawValue] as [String: Any])
        }

        // Stop tunnel
        router.addRoute(method: "POST", path: "/api/remote/stop", requiredRole: .admin) { request in
            let tunnel = CloudflareTunnelManager.shared
            tunnel.stopTunnel()
            let user = request.sessionUsername ?? "unknown"
            ActivityLogManager.shared.info(.webServer, "Tunnel stop requested by \(user)")
            AuditLogManager.shared.log(method: "POST", path: "/api/remote/stop", status: 200, remoteAddress: request.remoteAddress ?? "unknown", user: request.sessionUsername, detail: "stopped")
            return HTTPResponse.json(["ok": true, "status": tunnel.status.rawValue] as [String: Any])
        }

        // Restart tunnel
        router.addRoute(method: "POST", path: "/api/remote/restart", requiredRole: .admin) { request in
            let tunnel = CloudflareTunnelManager.shared
            var mode: TunnelMode? = nil
            if let body = request.body,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let modeRaw = json["mode"] as? String {
                mode = TunnelMode(rawValue: modeRaw)
            }
            tunnel.restartTunnel(mode: mode)
            let user = request.sessionUsername ?? "unknown"
            ActivityLogManager.shared.info(.webServer, "Tunnel restart requested by \(user)")
            AuditLogManager.shared.log(method: "POST", path: "/api/remote/restart", status: 200, remoteAddress: request.remoteAddress ?? "unknown", user: request.sessionUsername, detail: "restart")
            return HTTPResponse.json(["ok": true, "status": tunnel.status.rawValue] as [String: Any])
        }

        // Force stop tunnel (admin-only)
        router.addRoute(method: "POST", path: "/api/remote/force-stop", requiredRole: .admin) { request in
            let tunnel = CloudflareTunnelManager.shared
            tunnel.forceStop()
            let user = request.sessionUsername ?? "unknown"
            ActivityLogManager.shared.info(.webServer, "Tunnel force-stop requested by \(user)")
            AuditLogManager.shared.log(method: "POST", path: "/api/remote/force-stop", status: 200, remoteAddress: request.remoteAddress ?? "unknown", user: request.sessionUsername, detail: "force-stop")
            return HTTPResponse.json(["ok": true, "status": tunnel.status.rawValue] as [String: Any])
        }

        // Reset status (reconcile status with real process state)
        router.addRoute(method: "POST", path: "/api/remote/reset-status", requiredRole: .admin) { request in
            let tunnel = CloudflareTunnelManager.shared
            tunnel.reconcileStatus()
            let user = request.sessionUsername ?? "unknown"
            ActivityLogManager.shared.info(.webServer, "Tunnel reset-status requested by \(user)")
            AuditLogManager.shared.log(method: "POST", path: "/api/remote/reset-status", status: 200, remoteAddress: request.remoteAddress ?? "unknown", user: request.sessionUsername, detail: "reset-status")
            return HTTPResponse.json(["ok": true, "status": tunnel.status.rawValue] as [String: Any])
        }

        // Tunnel diagnostics
        router.addRoute(method: "GET", path: "/api/remote/diagnostics") { _ in
            let diag = CloudflareTunnelManager.shared.diagnostics()
            return HTTPResponse.json(["diagnostics": diag] as [String: Any])
        }

        // Setup status — state-driven wizard data
        router.addRoute(method: "GET", path: "/api/remote/setup-status") { _ in
            let tunnel = CloudflareTunnelManager.shared
            let settings = SettingsStore.shared
            let setup = tunnel.setupStatus()

            var result: [String: Any] = [
                "status": setup.status.rawValue,
                "statusDisplay": setup.status.displayName,
                "tunnelMode": settings.cloudflareTunnelMode.rawValue,
                "tunnelName": settings.cloudflareTunnelName,
                "hostname": settings.cloudflareHostname,
                "webServerPort": settings.webServerPort,
                "isRunning": tunnel.isRunning,
                "quickTunnelURL": tunnel.quickTunnelURL
            ]
            if let config = setup.config {
                result["configTunnel"] = config.tunnel
                result["configHostname"] = config.ingressHostname
                result["configService"] = config.ingressService
                result["configServicePort"] = config.parsedServicePort as Any
            }
            for (k, v) in setup.details {
                result[k] = v
            }
            return HTTPResponse.json(result)
        }

        // Save tunnel settings
        router.addRoute(method: "POST", path: "/api/remote/settings", requiredRole: .admin) { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                return HTTPResponse.error("Invalid JSON", status: 400)
            }
            let settings = SettingsStore.shared
            if let name = json["cloudflareTunnelName"] as? String { settings.cloudflareTunnelName = name }
            if let host = json["cloudflareHostname"] as? String { settings.cloudflareHostname = host }
            if let modeRaw = json["cloudflareTunnelMode"] as? String, let mode = TunnelMode(rawValue: modeRaw) {
                settings.cloudflareTunnelMode = mode
            }
            let user = request.sessionUsername ?? "unknown"
            ActivityLogManager.shared.info(.webServer, "Tunnel settings updated by \(user)")
            AuditLogManager.shared.log(
                method: "POST", path: "/api/remote/settings", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "save tunnel settings"
            )
            return HTTPResponse.json(["ok": true] as [String: Any])
        }

        // Generate config.yml content (preview)
        router.addRoute(method: "POST", path: "/api/remote/generate-config", requiredRole: .admin) { _ in
            let tunnel = CloudflareTunnelManager.shared
            let settings = SettingsStore.shared
            guard !settings.cloudflareTunnelName.isEmpty else {
                return HTTPResponse.error("Tunnel name not configured", status: 400)
            }
            guard !settings.cloudflareHostname.isEmpty else {
                return HTTPResponse.error("Hostname not configured", status: 400)
            }
            let content = tunnel.generateConfigYML()
            return HTTPResponse.json(["content": content, "config": content, "configPath": tunnel.configFilePath().path] as [String: Any])
        }

        // Write config.yml with backup
        router.addRoute(method: "POST", path: "/api/remote/write-config", requiredRole: .admin) { request in
            let tunnel = CloudflareTunnelManager.shared
            let settings = SettingsStore.shared
            guard !settings.cloudflareTunnelName.isEmpty else {
                return HTTPResponse.error("Tunnel name not configured", status: 400)
            }
            guard !settings.cloudflareHostname.isEmpty else {
                return HTTPResponse.error("Hostname not configured", status: 400)
            }
            let content = tunnel.generateConfigYML()
            let result = tunnel.writeConfigWithBackup(content: content)
            let user = request.sessionUsername ?? "unknown"
            if result.ok {
                ActivityLogManager.shared.info(.webServer, "Config.yml written by \(user)")
                AuditLogManager.shared.log(method: "POST", path: "/api/remote/write-config", status: 200, remoteAddress: request.remoteAddress ?? "unknown", user: request.sessionUsername, detail: "configPath=\(tunnel.configFilePath().path)")
                return HTTPResponse.json(["ok": true, "backupPath": result.backupPath as Any] as [String: Any])
            } else {
                return HTTPResponse.error("Failed to write config: \(result.error ?? "unknown")", status: 500)
            }
        }
    }
}
