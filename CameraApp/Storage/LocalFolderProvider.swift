import Foundation

final class LocalFolderProvider: StorageProvider {
    let type: StorageProviderType
    var displayName: String { type == .mountedFolder ? Strings.mountedFolder : Strings.localFolder }

    private let folderURL: URL

    init(path: String, type: StorageProviderType = .localFolder) {
        self.folderURL = URL(fileURLWithPath: path)
        self.type = type
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
        return fm.isWritableFile(atPath: folderURL.path)
    }

    func upload(fileAt localURL: URL, remotePath: String, progress: @escaping (Double) -> Void) async throws -> StorageResult {
        let fm = FileManager.default

        // Build date-based destination: MacMonitor/YYYY/MM/DD/photos|videos/fileName
        let destURL = buildDestinationURL(for: remotePath)

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

        // Post-upload verification: file exists and size matches
        let sourceAttrs = try fm.attributesOfItem(atPath: localURL.path)
        let sourceSize = (sourceAttrs[.size] as? Int64) ?? 0

        guard fm.fileExists(atPath: destURL.path) else {
            throw StorageError.verificationFailed("File not found after copy: \(destURL.path)")
        }

        let destAttrs = try fm.attributesOfItem(atPath: destURL.path)
        let destSize = (destAttrs[.size] as? Int64) ?? 0

        guard destSize == sourceSize else {
            // Clean up mismatched file
            try? fm.removeItem(at: destURL)
            throw StorageError.verificationFailed("Size mismatch: expected \(sourceSize), got \(destSize)")
        }

        return StorageResult(
            remotePath: destURL.path.replacingOccurrences(of: folderURL.path + "/", with: ""),
            remoteFileID: destURL.path,
            remoteURL: destURL.absoluteString,
            fileSize: destSize
        )
    }

    func delete(remotePath: String) async throws {
        let url = folderURL.appendingPathComponent(remotePath)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func fileExists(at remotePath: String) async -> Bool {
        let url = folderURL.appendingPathComponent(remotePath)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Build date-based destination URL: baseDir/MacMonitor/YYYY/MM/DD/category/fileName
    private func buildDestinationURL(for remotePath: String) -> URL {
        let fileName = (remotePath as NSString).lastPathComponent
        let category = categoryFromPath(remotePath)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let datePath = formatter.string(from: Date())
        return folderURL
            .appendingPathComponent("MacMonitor")
            .appendingPathComponent(datePath)
            .appendingPathComponent(category)
            .appendingPathComponent(fileName)
    }

    private func categoryFromPath(_ path: String) -> String {
        let lower = path.lowercased()
        if lower.contains("video") || lower.contains(".mp4") || lower.contains(".mov") {
            return "videos"
        }
        return "photos"
    }
}

enum StorageError: LocalizedError {
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .verificationFailed(let detail): return "Verification failed: \(detail)"
        }
    }
}
