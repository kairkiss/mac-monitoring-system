import Foundation

struct StorageResult {
    let remotePath: String
    let remoteFileID: String?
    let remoteURL: String?
    let fileSize: Int64
}

protocol StorageProvider: AnyObject {
    var type: StorageProviderType { get }
    var displayName: String { get }
    var isConfigured: Bool { get }
    func isAvailable() async -> Bool
    func upload(fileAt localURL: URL, remotePath: String, progress: @escaping (Double) -> Void) async throws -> StorageResult
    func delete(remotePath: String) async throws
    func fileExists(at remotePath: String) async throws -> Bool
}
