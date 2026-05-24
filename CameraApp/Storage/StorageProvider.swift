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
    func testConnectionDetailed() async -> StorageDiagnostics
}

extension StorageProvider {
    func testConnectionDetailed() async -> StorageDiagnostics {
        let connected = await isAvailable()
        return StorageDiagnostics(
            providerType: type.rawValue, isConnected: connected, authenticatedEmail: nil,
            lastTestDate: Date(), lastTestSuccess: connected,
            lastTestError: connected ? nil : "Connection test failed",
            lastTestErrorClass: connected ? nil : .unknown,
            rootFolderName: nil, rootFolderExists: nil,
            quotaUsedGB: nil, quotaTotalGB: nil,
            recentUploadCount: 0, recentFailureCount: 0
        )
    }
}
