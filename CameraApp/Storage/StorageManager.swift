import Foundation

final class StorageManager: ObservableObject {
    static let shared = StorageManager()

    @Published private(set) var activeProvider: StorageProvider?
    @Published private(set) var activeProviderType: StorageProviderType = .none
    @Published private(set) var lastError: String?

    private init() {}

    func configure() {
        let settings = SettingsStore.shared
        let type = StorageProviderType(rawValue: settings.activeStorageProviderType) ?? .none

        activeProviderType = type

        switch type {
        case .none:
            activeProvider = nil
            lastError = nil
        case .localFolder:
            let path = settings.localFolderPath
            if !path.isEmpty {
                activeProvider = LocalFolderProvider(path: path)
                lastError = nil
            } else {
                activeProvider = nil
                lastError = "Local folder path not configured"
            }
        case .mountedFolder:
            let path = settings.mountedFolderPath
            if !path.isEmpty {
                activeProvider = LocalFolderProvider(path: path, type: .mountedFolder)
                lastError = nil
            } else {
                activeProvider = nil
                lastError = "Mounted folder path not configured"
            }
        case .googleDrive:
            let auth = GoogleDriveAuthManager.shared
            let clientID = settings.googleDriveClientID
            let clientSecret = settings.googleDriveClientSecret

            if clientID.isEmpty || clientSecret.isEmpty {
                activeProvider = nil
                lastError = "Google Drive not configured — enter Client ID and Client Secret in Settings"
                ActivityLogManager.shared.info(.upload, "Google Drive not configured — missing credentials")
            } else if !auth.isAuthenticated {
                activeProvider = nil
                if auth.needsReconnect {
                    lastError = "Google Drive needs reconnect — please sign in again"
                } else {
                    lastError = "Google Drive not authenticated — sign in via Settings"
                }
                ActivityLogManager.shared.info(.upload, "Google Drive not authenticated — sign in via Settings")
            } else {
                let provider = GoogleDriveProvider()
                if provider.isConfigured {
                    activeProvider = provider
                    lastError = nil
                } else {
                    activeProvider = nil
                    lastError = "Google Drive provider not ready — check credentials"
                }
            }
        case .webdav:
            activeProvider = nil
            lastError = "WebDAV provider is planned and not fully implemented yet"
            ActivityLogManager.shared.warning(.upload, "WebDAV provider not yet implemented")
        }

        // Reattach waiting upload jobs to the new provider
        UploadQueueManager.shared.reattachWaitingJobs()
    }

    func testConnection() async -> Bool {
        guard let provider = activeProvider else { return false }
        return await provider.isAvailable()
    }

    func testConnectionDetailed() async -> StorageDiagnostics {
        guard let provider = activeProvider else {
            return StorageDiagnostics(
                providerType: activeProviderType.rawValue,
                isConnected: false,
                authenticatedEmail: nil,
                lastTestDate: Date(),
                lastTestSuccess: false,
                lastTestError: lastError ?? "No provider configured",
                lastTestErrorClass: nil,
                rootFolderName: nil,
                rootFolderExists: nil,
                quotaUsedGB: nil,
                quotaTotalGB: nil,
                recentUploadCount: 0,
                recentFailureCount: 0
            )
        }
        return await provider.testConnectionDetailed()
    }
}
