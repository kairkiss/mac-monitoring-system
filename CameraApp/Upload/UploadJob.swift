import Foundation

struct UploadJob: Codable, Identifiable {
    let id: String
    let fileName: String
    let localPath: String
    let remotePath: String
    let providerType: String
    var status: UploadJobStatus = .pending
    var progress: Double = 0
    var attempts: Int = 0
    var maxRetries: Int = 3
    var lastError: String?
    var createdAt: Date = Date()
    var startedAt: Date?
    var completedAt: Date?
    var fileSize: Int64?
    var nextRetryAt: Date?
    var lastAttemptAt: Date?
    var retryDelaySeconds: Int?
    var errorClass: String?

    init(fileName: String, localPath: String, remotePath: String, providerType: String) {
        self.id = UUID().uuidString
        self.fileName = fileName
        self.localPath = localPath
        self.remotePath = remotePath
        self.providerType = providerType
    }
}
