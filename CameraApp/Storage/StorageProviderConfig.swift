import Foundation

struct LocalFolderConfig {
    var path: String
}

struct MountedFolderConfig {
    var path: String
}

struct GoogleDriveConfig {
    var folderID: String
}

struct WebDAVConfig {
    var url: String
    var username: String
    var basePath: String
    var allowInsecure: Bool
}
