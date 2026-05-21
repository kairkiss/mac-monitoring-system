import Foundation

enum StorageProviderType: String, Codable, CaseIterable {
    case none
    case localFolder
    case mountedFolder
    case googleDrive
    case webdav

    var displayName: String {
        switch self {
        case .none: return Strings.none
        case .localFolder: return Strings.localFolder
        case .mountedFolder: return Strings.mountedFolder
        case .googleDrive: return Strings.googleDrive
        case .webdav: return Strings.webdav
        }
    }
}
