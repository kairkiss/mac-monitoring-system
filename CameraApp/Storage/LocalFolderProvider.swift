import Foundation

final class LocalFolderProvider: StorageProvider {
    let type: StorageProviderType = .localFolder
    var displayName: String { Strings.localFolder }

    private let folderURL: URL

    init(path: String) {
        self.folderURL = URL(fileURLWithPath: path)
    }

    var isConfigured: Bool {
        !folderURL.path.isEmpty
    }

    func isAvailable() async -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        // Check writability
        return fm.isWritableFile(atPath: folderURL.path)
    }

    func upload(fileAt localURL: URL, remotePath: String, progress: @escaping (Double) -> Void) async throws -> StorageResult {
        let destURL = folderURL.appendingPathComponent(remotePath)
        let fm = FileManager.default

        // Create intermediate directories
        let dir = destURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Remove existing file at destination
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }

        // Copy file
        try fm.copyItem(at: localURL, to: destURL)

        progress(1.0)

        let attrs = try fm.attributesOfItem(atPath: destURL.path)
        let fileSize = (attrs[.size] as? Int64) ?? 0

        return StorageResult(
            remotePath: remotePath,
            remoteFileID: destURL.path,
            remoteURL: destURL.absoluteString,
            fileSize: fileSize
        )
    }

    func delete(remotePath: String) throws {
        let url = folderURL.appendingPathComponent(remotePath)
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    func fileExists(at remotePath: String) async -> Bool {
        let url = folderURL.appendingPathComponent(remotePath)
        return FileManager.default.fileExists(atPath: url.path)
    }
}
