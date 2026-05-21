import Foundation

final class StorageManager: ObservableObject {
    static let shared = StorageManager()

    @Published private(set) var activeProvider: StorageProvider?
    @Published private(set) var activeProviderType: StorageProviderType = .none

    private init() {}

    func configure() {
        let settings = SettingsStore.shared
        let type = StorageProviderType(rawValue: settings.activeStorageProviderType) ?? .none

        activeProviderType = type

        switch type {
        case .none:
            activeProvider = nil
        case .localFolder:
            let path = settings.localFolderPath
            if !path.isEmpty {
                activeProvider = LocalFolderProvider(path: path)
            } else {
                activeProvider = nil
            }
        case .mountedFolder:
            let path = settings.mountedFolderPath
            if !path.isEmpty {
                activeProvider = LocalFolderProvider(path: path, type: .mountedFolder)
            } else {
                activeProvider = nil
            }
        case .googleDrive:
            // TODO: GoogleDriveProvider — requires OAuth setup
            activeProvider = nil
            ActivityLogManager.shared.warning(.upload, "Google Drive provider not yet configured")
        case .webdav:
            // TODO: WebDAVProvider — requires URL + credentials
            activeProvider = nil
            ActivityLogManager.shared.warning(.upload, "WebDAV provider not yet configured")
        }
    }

    func testConnection() async -> Bool {
        guard let provider = activeProvider else { return false }
        return await provider.isAvailable()
    }
}
