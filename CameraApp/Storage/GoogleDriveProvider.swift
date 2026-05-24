import Foundation

final class GoogleDriveProvider: StorageProvider {
    let type: StorageProviderType = .googleDrive
    var displayName: String { Strings.googleDrive }

    private let authManager = GoogleDriveAuthManager.shared
    private let kc = KeychainService.shared

    // Chunk size for resumable upload (8MB)
    private let chunkSize = 8 * 1024 * 1024

    var isConfigured: Bool {
        !googleDriveClientID.isEmpty && !googleDriveClientSecret.isEmpty && authManager.isAuthenticated
    }

    func isAvailable() async -> Bool {
        guard !googleDriveClientID.isEmpty, !googleDriveClientSecret.isEmpty else { return false }
        guard authManager.isAuthenticated else { return false }
        do {
            let token = try await authManager.getValidAccessToken(
                clientID: googleDriveClientID,
                clientSecret: googleDriveClientSecret
            )
            guard let url = URL(string: "https://www.googleapis.com/drive/v3/about?fields=user") else { return false }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Upload (Resumable, No-Overwrite)

    func upload(fileAt localURL: URL, remotePath: String, progress: @escaping (Double) -> Void) async throws -> StorageResult {
        guard !googleDriveClientID.isEmpty, !googleDriveClientSecret.isEmpty else {
            throw GoogleDriveError.notConfigured
        }
        guard authManager.isAuthenticated else {
            throw GoogleDriveError.notAuthenticated
        }

        let token = try await authManager.getValidAccessToken(
            clientID: googleDriveClientID,
            clientSecret: googleDriveClientSecret
        )

        // Ensure parent folder exists and get its ID
        let parentID = try await ensureFolderPath(remotePath: remotePath, token: token)

        // Get file info
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw GoogleDriveError.fileNotFound(localURL.lastPathComponent)
        }

        let fileAttributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        let fileSize = (fileAttributes[.size] as? Int64) ?? 0
        let originalName = localURL.lastPathComponent
        let mimeType = mimeTypeForPath(localURL.path)

        // Generate unique filename — never overwrite existing remote files
        let uniqueName = try await generateUniqueName(
            name: originalName,
            parentID: parentID,
            token: token
        )

        // Initiate resumable upload (always POST for new file)
        let uploadURI = try await initiateResumableUpload(
            fileName: uniqueName,
            mimeType: mimeType,
            parentID: parentID,
            fileSize: fileSize,
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
        if let verifySize = try? await getFileSize(fileID: fileID, token: token), verifySize != fileSize {
            throw StorageError.verificationFailed("Size mismatch after Google Drive upload")
        }

        // Build the actual remote path (with unique name)
        let actualRemotePath = buildActualRemotePath(remotePath: remotePath, uniqueName: uniqueName)

        // Store folder ID for future lookups
        if kc.googleDriveRootFolderID.isEmpty {
            if let rootFolderID = try? await findRootFolderID(token: token) {
                kc.googleDriveRootFolderID = rootFolderID
            }
        }

        let driveURL = "https://drive.google.com/file/d/\(fileID)/view"
        return StorageResult(
            remotePath: actualRemotePath,
            remoteFileID: fileID,
            remoteURL: driveURL,
            fileSize: fileSize
        )
    }

    // MARK: - Delete (by file ID, not path)

    func delete(remotePath: String) async throws {
        guard !googleDriveClientID.isEmpty, !googleDriveClientSecret.isEmpty else {
            throw GoogleDriveError.notConfigured
        }

        let token = try await authManager.getValidAccessToken(
            clientID: googleDriveClientID,
            clientSecret: googleDriveClientSecret
        )

        guard let fileID = try await resolveFileID(from: remotePath, token: token) else {
            return
        }

        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileID)") else {
            throw GoogleDriveError.invalidURL
        }

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
        guard !googleDriveClientID.isEmpty, !googleDriveClientSecret.isEmpty else { return false }
        guard let token = try? await authManager.getValidAccessToken(
            clientID: googleDriveClientID,
            clientSecret: googleDriveClientSecret
        ) else { return false }

        return (try? await resolveFileID(from: remotePath, token: token)) != nil
    }

    // MARK: - Folder Management

    private func ensureFolderPath(remotePath: String, token: String) async throws -> String {
        let settings = SettingsStore.shared
        let rootFolderName = settings.googleDriveRootFolderName.isEmpty ? "MacMonitor" : settings.googleDriveRootFolderName

        // Start from cached root folder ID or "root"
        var currentFolderID: String
        if !settings.googleDriveFolderID.isEmpty {
            currentFolderID = settings.googleDriveFolderID
        } else if !kc.googleDriveRootFolderID.isEmpty {
            currentFolderID = kc.googleDriveRootFolderID
        } else {
            currentFolderID = "root"
        }

        // Build path: RootFolder/Category/
        let category = categoryFromPath(remotePath)
        let pathComponents = [rootFolderName, category]

        for component in pathComponents {
            currentFolderID = try await findOrCreateFolder(name: component, parentID: currentFolderID, token: token)
        }

        // Cache the root folder ID
        if kc.googleDriveRootFolderID.isEmpty {
            if let rootID = try? await findOrCreateFolder(name: rootFolderName, parentID: "root", token: token) {
                kc.googleDriveRootFolderID = rootID
            }
        }

        return currentFolderID
    }

    private func findRootFolderID(token: String) async throws -> String {
        let settings = SettingsStore.shared
        let rootFolderName = settings.googleDriveRootFolderName.isEmpty ? "MacMonitor" : settings.googleDriveRootFolderName
        return try await findOrCreateFolder(name: rootFolderName, parentID: "root", token: token)
    }

    private func findOrCreateFolder(name: String, parentID: String, token: String) async throws -> String {
        if let existing = try await findFile(name: name, parentID: parentID, token: token, mimeType: "application/vnd.google-apps.folder") {
            return existing
        }
        return try await createFolder(name: name, parentID: parentID, token: token)
    }

    private func createFolder(name: String, parentID: String, token: String) async throws -> String {
        let metadata: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder",
            "parents": [parentID]
        ]

        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files") else {
            throw GoogleDriveError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleDriveError.apiError("Folder creation failed")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let folderID = json["id"] as? String else {
            throw GoogleDriveError.apiError("Invalid folder creation response")
        }

        return folderID
    }

    // MARK: - No-Overwrite: Generate Unique Name

    private func generateUniqueName(name: String, parentID: String, token: String) async throws -> String {
        let existing = try await findFile(name: name, parentID: parentID, token: token)
        if existing == nil {
            return name
        }

        let ext = (name as NSString).pathExtension
        let baseName = (name as NSString).deletingPathExtension
        let timestamp = Int(Date().timeIntervalSince1970)

        var candidate: String
        var counter = 0
        repeat {
            if counter == 0 {
                candidate = ext.isEmpty ? "\(baseName)_\(timestamp)" : "\(baseName)_\(timestamp).\(ext)"
            } else {
                candidate = ext.isEmpty ? "\(baseName)_\(timestamp)_\(counter)" : "\(baseName)_\(timestamp)_\(counter).\(ext)"
            }
            counter += 1
            let found = try await findFile(name: candidate, parentID: parentID, token: token)
            if found == nil {
                return candidate
            }
        } while counter < 100

        let uuid = UUID().uuidString.prefix(8)
        return ext.isEmpty ? "\(baseName)_\(uuid)" : "\(baseName)_\(uuid).\(ext)"
    }

    // MARK: - Resumable Upload

    private func initiateResumableUpload(
        fileName: String,
        mimeType: String,
        parentID: String,
        fileSize: Int64,
        token: String
    ) async throws -> URL {
        let metadata: [String: Any] = [
            "name": fileName,
            "mimeType": mimeType,
            "parents": [parentID]
        ]

        let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)

        guard let url = URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable") else {
            throw GoogleDriveError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forReadingFrom: localURL)
        } catch {
            throw GoogleDriveError.fileNotFound("Cannot open file: \(localURL.lastPathComponent)")
        }
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
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let id = json["id"] as? String {
                    fileID = id
                }
            } else if httpResponse.statusCode == 401 {
                throw GoogleDriveError.apiError("Authentication expired. Please sign in again.")
            } else if httpResponse.statusCode == 403 {
                throw GoogleDriveError.apiError("Permission denied or storage quota exceeded.")
            } else if httpResponse.statusCode == 429 {
                throw GoogleDriveError.apiError("Rate limited. Will retry later.")
            } else {
                throw GoogleDriveError.apiError("Chunk upload failed: HTTP \(httpResponse.statusCode)")
            }

            offset += Int64(currentChunkSize)
            let currentOffset = offset
            let currentFileSize = fileSize
            await MainActor.run { progress(Double(currentOffset) / Double(currentFileSize)) }
        }

        guard let resultID = fileID else {
            throw GoogleDriveError.apiError("Upload completed but no file ID returned")
        }

        return resultID
    }

    // MARK: - Queries

    private func findFile(name: String, parentID: String, token: String, mimeType: String? = nil) async throws -> String? {
        let escapedName = name.replacingOccurrences(of: "'", with: "\\'")
        var query = "name='\(escapedName)' and '\(parentID)' in parents and trashed=false"
        if let mime = mimeType {
            query += " and mimeType='\(mime)'"
        }

        guard var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: "files(id)"),
            URLQueryItem(name: "spaces", value: "drive")
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [[String: Any]],
              let first = files.first,
              let id = first["id"] as? String else {
            return nil
        }

        return id
    }

    /// Resolve file ID from remotePath — supports both file ID in path and path-based lookup
    private func resolveFileID(from remotePath: String, token: String) async throws -> String? {
        if !remotePath.contains("/") && !remotePath.isEmpty && remotePath.count >= 10 {
            guard let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(remotePath)?fields=id") else {
                return try await findFileByStoredPath(remotePath: remotePath, token: token)
            }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (_, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                return remotePath
            }
        }

        return try await findFileByStoredPath(remotePath: remotePath, token: token)
    }

    /// Find file by stored path — uses cached folder IDs, not date-based reconstruction
    private func findFileByStoredPath(remotePath: String, token: String) async throws -> String? {
        let settings = SettingsStore.shared

        var currentFolderID: String
        if !kc.googleDriveRootFolderID.isEmpty {
            currentFolderID = kc.googleDriveRootFolderID
        } else if !settings.googleDriveFolderID.isEmpty {
            currentFolderID = settings.googleDriveFolderID
        } else {
            currentFolderID = "root"
        }

        let components = remotePath.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return nil }

        for i in 0..<(components.count - 1) {
            guard let folderID = try await findFile(
                name: components[i],
                parentID: currentFolderID,
                token: token,
                mimeType: "application/vnd.google-apps.folder"
            ) else {
                return nil
            }
            currentFolderID = folderID
        }

        let fileName = components.last!
        return try await findFile(name: fileName, parentID: currentFolderID, token: token)
    }

    func getFileSize(fileID: String, token: String) async throws -> Int64 {
        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileID)?fields=size") else {
            throw GoogleDriveError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw GoogleDriveError.apiError("Failed to get file size")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let size = json["size"] as? String,
              let sizeInt = Int64(size) else {
            return 0
        }

        return sizeInt
    }

    // MARK: - Helpers

    private func buildActualRemotePath(remotePath: String, uniqueName: String) -> String {
        let settings = SettingsStore.shared
        let rootFolderName = settings.googleDriveRootFolderName.isEmpty ? "MacMonitor" : settings.googleDriveRootFolderName
        let category = categoryFromPath(remotePath)
        return "\(rootFolderName)/\(category)/\(uniqueName)"
    }

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

    // MARK: - Google API Credentials (from Keychain)

    private var googleDriveClientID: String {
        SettingsStore.shared.googleDriveClientID
    }

    private var googleDriveClientSecret: String {
        KeychainService.shared.googleDriveClientSecret
    }
}

enum GoogleDriveError: LocalizedError {
    case apiError(String)
    case invalidURL
    case notConfigured
    case notAuthenticated
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let detail): return "Google Drive API error: \(detail)"
        case .invalidURL: return "Invalid URL"
        case .notConfigured: return "Google Drive is not configured. Please enter Client ID and Client Secret in Settings."
        case .notAuthenticated: return "Not authenticated with Google Drive. Please sign in."
        case .fileNotFound(let name): return "File not found: \(name)"
        }
    }
}
