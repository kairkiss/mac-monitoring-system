import Foundation

final class GoogleDriveProvider: StorageProvider {
    let type: StorageProviderType = .googleDrive
    var displayName: String { Strings.googleDrive }

    private let authManager = GoogleDriveAuthManager.shared
    private let kc = KeychainService.shared

    // Chunk size for resumable upload (8MB)
    private let chunkSize = 8 * 1024 * 1024

    var isConfigured: Bool {
        authManager.isAuthenticated
    }

    func isAvailable() async -> Bool {
        guard authManager.isAuthenticated else { return false }
        do {
            let token = try await authManager.getValidAccessToken(
                clientID: googleDriveClientID,
                clientSecret: googleDriveClientSecret
            )
            let url = URL(string: "https://www.googleapis.com/drive/v3/about?fields=user")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Upload (Resumable)

    func upload(fileAt localURL: URL, remotePath: String, progress: @escaping (Double) -> Void) async throws -> StorageResult {
        let token = try await authManager.getValidAccessToken(
            clientID: googleDriveClientID,
            clientSecret: googleDriveClientSecret
        )

        // Ensure parent folder exists
        let parentID = try await ensureFolderPath(remotePath: remotePath, token: token)

        // Get file info
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        let fileSize = (fileAttributes[.size] as? Int64) ?? 0
        let fileName = localURL.lastPathComponent
        let mimeType = mimeTypeForPath(localURL.path)

        // Check if file already exists (for replacement)
        let existingFileID = try? await findFile(name: fileName, parentID: parentID, token: token)

        // Initiate resumable upload
        let uploadURI = try await initiateResumableUpload(
            fileName: fileName,
            mimeType: mimeType,
            parentID: parentID,
            fileSize: fileSize,
            existingFileID: existingFileID,
            token: token
        )

        // Upload in chunks
        let fileID = try await uploadChunks(
            fileAt: localURL,
            fileSize: fileSize,
            uploadURI: uploadURI,
            progress: progress,
            token: token
        )

        // Verify
        guard let verifySize = try? await getFileSize(fileID: fileID, token: token),
              verifySize == fileSize else {
            throw StorageError.verificationFailed("Size mismatch after Google Drive upload")
        }

        let driveURL = "https://drive.google.com/file/d/\(fileID)/view"
        return StorageResult(
            remotePath: remotePath,
            remoteFileID: fileID,
            remoteURL: driveURL,
            fileSize: fileSize
        )
    }

    // MARK: - Delete

    func delete(remotePath: String) async throws {
        let token = try await authManager.getValidAccessToken(
            clientID: googleDriveClientID,
            clientSecret: googleDriveClientSecret
        )

        guard let fileID = try await findFileByPath(remotePath: remotePath, token: token) else {
            return
        }

        let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard status == 204 || status == 200 || status == 404 else {
            throw GoogleDriveError.apiError("Delete failed: HTTP \(status)")
        }
    }

    // MARK: - File Exists

    func fileExists(at remotePath: String) async -> Bool {
        guard let token = try? await authManager.getValidAccessToken(
            clientID: googleDriveClientID,
            clientSecret: googleDriveClientSecret
        ) else { return false }

        return (try? await findFileByPath(remotePath: remotePath, token: token)) != nil
    }

    // MARK: - Folder Management

    func ensureFolderPath(remotePath: String, token: String) async throws -> String {
        let settings = SettingsStore.shared
        var currentFolderID = settings.googleDriveFolderID.isEmpty ? "root" : settings.googleDriveFolderID

        // Create MacMonitor/Date/Category subfolders
        let fileName = (remotePath as NSString).lastPathComponent
        let category = categoryFromPath(remotePath)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let datePath = formatter.string(from: Date())
        let pathComponents = ["MacMonitor"] + datePath.split(separator: "/").map(String.init) + [category]

        for component in pathComponents {
            currentFolderID = try await findOrCreateFolder(name: component, parentID: currentFolderID, token: token)
        }

        return currentFolderID
    }

    func findOrCreateFolder(name: String, parentID: String, token: String) async throws -> String {
        if let existing = try await findFile(name: name, parentID: parentID, token: token, mimeType: "application/vnd.google-apps.folder") {
            return existing
        }

        return try await createFolder(name: name, parentID: parentID, token: token)
    }

    func createFolder(name: String, parentID: String, token: String) async throws -> String {
        let metadata: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder",
            "parents": [parentID]
        ]

        let url = URL(string: "https://www.googleapis.com/drive/v3/files")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleDriveError.apiError("Folder creation failed")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let folderID = json["id"] as? String else {
            throw GoogleDriveError.apiError("Invalid folder creation response")
        }

        return folderID
    }

    // MARK: - Resumable Upload

    private func initiateResumableUpload(
        fileName: String,
        mimeType: String,
        parentID: String,
        fileSize: Int64,
        existingFileID: String?,
        token: String
    ) async throws -> URL {
        let metadata: [String: Any] = [
            "name": fileName,
            "mimeType": mimeType,
            "parents": [parentID]
        ]

        let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)

        var urlString: String
        var httpMethod: String

        if let fileID = existingFileID {
            urlString = "https://www.googleapis.com/upload/drive/v3/files/\(fileID)?uploadType=resumable"
            httpMethod = "PATCH"
        } else {
            urlString = "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable"
            httpMethod = "POST"
        }

        guard let url = URL(string: urlString) else { throw GoogleDriveError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("\(metadataJSON.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("\(fileSize)", forHTTPHeaderField: "X-Upload-Content-Length")
        request.setValue(mimeType, forHTTPHeaderField: "X-Upload-Content-Type")
        request.httpBody = metadataJSON

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let uploadURI = httpResponse.value(forHTTPHeaderField: "Location"),
              let uploadURL = URL(string: uploadURI) else {
            throw GoogleDriveError.apiError("Failed to initiate resumable upload")
        }

        return uploadURL
    }

    private func uploadChunks(
        fileAt localURL: URL,
        fileSize: Int64,
        uploadURI: URL,
        progress: @escaping (Double) -> Void,
        token: String
    ) async throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: localURL)
        defer { try? fileHandle.close() }

        var offset: Int64 = 0
        var fileID: String?

        while offset < fileSize {
            let remaining = fileSize - offset
            let currentChunkSize = Int(min(Int64(chunkSize), remaining))
            let endByte = offset + Int64(currentChunkSize) - 1

            fileHandle.seek(toFileOffset: UInt64(offset))
            let chunkData = fileHandle.readData(ofLength: currentChunkSize)

            var request = URLRequest(url: uploadURI)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("bytes \(offset)-\(endByte)/\(fileSize)", forHTTPHeaderField: "Content-Range")
            request.setValue("\(currentChunkSize)", forHTTPHeaderField: "Content-Length")
            request.httpBody = chunkData

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GoogleDriveError.apiError("No HTTP response")
            }

            if httpResponse.statusCode == 308 {
                // Resume incomplete — continue
            } else if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                // Upload complete
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let id = json["id"] as? String {
                    fileID = id
                }
            } else {
                throw GoogleDriveError.apiError("Chunk upload failed: HTTP \(httpResponse.statusCode)")
            }

            offset += Int64(currentChunkSize)
            await MainActor.run { progress(Double(offset) / Double(fileSize)) }
        }

        guard let resultID = fileID else {
            throw GoogleDriveError.apiError("Upload completed but no file ID returned")
        }

        return resultID
    }

    // MARK: - Queries

    func findFile(name: String, parentID: String, token: String, mimeType: String? = nil) async throws -> String? {
        var query = "name='\(name.replacingOccurrences(of: "'", with: "\\'"))' and '\(parentID)' in parents and trashed=false"
        if let mime = mimeType {
            query += " and mimeType='\(mime)'"
        }

        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: "files(id)"),
            URLQueryItem(name: "spaces", value: "drive")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [[String: Any]],
              let first = files.first,
              let id = first["id"] as? String else {
            return nil
        }

        return id
    }

    func findFileByPath(remotePath: String, token: String) async throws -> String? {
        let settings = SettingsStore.shared
        var currentFolderID = settings.googleDriveFolderID.isEmpty ? "root" : settings.googleDriveFolderID

        let fileName = (remotePath as NSString).lastPathComponent
        let category = categoryFromPath(remotePath)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let datePath = formatter.string(from: Date())
        let pathComponents = ["MacMonitor"] + datePath.split(separator: "/").map(String.init) + [category]

        for component in pathComponents {
            guard let folderID = try await findFile(name: component, parentID: currentFolderID, token: token, mimeType: "application/vnd.google-apps.folder") else {
                return nil
            }
            currentFolderID = folderID
        }

        return try await findFile(name: fileName, parentID: currentFolderID, token: token)
    }

    func getFileSize(fileID: String, token: String) async throws -> Int64 {
        let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileID)?fields=size")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GoogleDriveError.apiError("Failed to get file size")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let size = json["size"] as? String,
              let sizeInt = Int64(size) else {
            return 0
        }

        return sizeInt
    }

    // MARK: - Helpers

    private func categoryFromPath(_ path: String) -> String {
        let lower = path.lowercased()
        if lower.contains("video") || lower.contains(".mp4") || lower.contains(".mov") {
            return "videos"
        }
        return "photos"
    }

    private func mimeTypeForPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "heic": return "image/heic"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "avi": return "video/x-msvideo"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Google API Credentials

    private var googleDriveClientID: String {
        SettingsStore.shared.googleDriveClientID
    }

    private var googleDriveClientSecret: String {
        SettingsStore.shared.googleDriveClientSecret
    }
}

enum GoogleDriveError: LocalizedError {
    case apiError(String)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .apiError(let detail): return "Google Drive API error: \(detail)"
        case .invalidURL: return "Invalid URL"
        }
    }
}
