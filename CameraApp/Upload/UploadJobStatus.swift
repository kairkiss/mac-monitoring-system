import Foundation

enum UploadJobStatus: String, Codable {
    case pending
    case uploading
    case completed
    case failed
    case cancelled
    case retrying
}
