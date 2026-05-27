import Foundation

struct APIMediaHandler {
    static func register(router: WebRouter) {
        // List media (paginated, filtered)
        router.addRoute(method: "GET", path: "/api/media") { request in
            let media = MediaLibraryManager.shared
            let index = MediaIndexStore.shared

            let page = Int(request.queryParameters["page"] ?? "1") ?? 1
            let perPage = min(Int(request.queryParameters["perPage"] ?? "24") ?? 24, 100)
            let type = request.queryParameters["type"]
            let source = request.queryParameters["source"]
            let uploadStatus = request.queryParameters["uploadStatus"]
            let search = request.queryParameters["search"]?.lowercased()
            let favorite = request.queryParameters["favorite"]

            var allFiles: [(String, String)] = []

            let photos = media.photoFileNames
            let videos = media.videoFileNames

            if type == nil || type == "photo" {
                allFiles.append(contentsOf: photos.map { ($0, "photo") })
            }
            if type == nil || type == "video" {
                allFiles.append(contentsOf: videos.map { ($0, "video") })
            }

            // Also include archived entries (localDeleted but still in index)
            let archivedKeys = index.localDeletedItems().filter { name in
                !allFiles.contains(where: { $0.0 == name })
            }
            for key in archivedKeys {
                let entry = index.entry(for: key)
                let mediaType = key.lowercased().contains("video") ? "video" : "photo"
                if type == nil || type == mediaType {
                    allFiles.append((key, mediaType))
                }
            }

            // Apply filters
            var filtered = allFiles
            if let source = source, let src = MediaSource(rawValue: source) {
                filtered = filtered.filter { index.entry(for: $0.0).source == src }
            }
            if let uploadStatus = uploadStatus, let us = UploadEntryStatus(rawValue: uploadStatus) {
                filtered = filtered.filter { index.entry(for: $0.0).uploadStatus == us }
            }
            if favorite == "true" {
                filtered = filtered.filter { index.isFavorite($0.0) }
            }
            if let search = search, !search.isEmpty {
                filtered = filtered.filter { $0.0.lowercased().contains(search) }
            }

            // Sort by date (newest first)
            filtered.sort { $0.0 > $1.0 }

            let total = filtered.count
            let start = (page - 1) * perPage
            let end = min(start + perPage, total)

            var items: [[String: Any]] = []
            if start < total {
                for (fileName, mediaType) in filtered[start..<end] {
                    let entry = index.entry(for: fileName)
                    let localExists = entry.localOriginalExists
                    let hasThumb = media.thumbnailURL(for: fileName) != nil
                    let fileSize = entry.fileSize
                    items.append([
                        "fileName": fileName,
                        "type": mediaType,
                        "source": entry.source.rawValue,
                        "isFavorite": entry.isFavorite,
                        "protected": entry.protected,
                        "uploadStatus": entry.uploadStatus.rawValue,
                        "verified": entry.verified,
                        "localOriginalExists": localExists,
                        "remoteURL": entry.remoteURL ?? "",
                        "remoteFileID": entry.remoteFileID ?? "",
                        "providerType": entry.providerType ?? "",
                        "fileSize": fileSize,
                        "hasThumbnail": hasThumb
                    ] as [String: Any])
                }
            }

            return HTTPResponse.json([
                "items": items,
                "total": total,
                "page": page,
                "perPage": perPage,
                "totalPages": max(1, (total + perPage - 1) / perPage)
            ] as [String: Any])
        }

        // Get single media item detail
        router.addRoute(method: "GET", path: "/api/media/:id") { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            let index = MediaIndexStore.shared
            let entry = index.entry(for: fileName)
            let media = MediaLibraryManager.shared
            let localExists = media.photoURL(for: fileName) != nil || media.videoURL(for: fileName) != nil
            let isPhoto = media.photoFileNames.contains(fileName)

            return HTTPResponse.json([
                "fileName": fileName,
                "type": isPhoto ? "photo" : "video",
                "source": entry.source.rawValue,
                "isFavorite": entry.isFavorite,
                "protected": entry.protected,
                "uploadStatus": entry.uploadStatus.rawValue,
                "verified": entry.verified,
                "localOriginalExists": localExists,
                "remoteURL": entry.remoteURL ?? "",
                "remoteFileID": entry.remoteFileID ?? "",
                "fileSize": entry.fileSize,
                "uploadProvider": entry.uploadProvider ?? "",
                "providerType": entry.providerType ?? entry.uploadProvider ?? "",
                "uploadRemotePath": entry.uploadRemotePath ?? "",
                "uploadDate": entry.uploadDate.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                "verifiedAt": entry.verifiedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                "localDeletedAt": entry.localDeletedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                "uploadLastError": entry.uploadLastError ?? ""
            ] as [String: Any])
        }

        // Get media file (download) — with Range support
        router.addRoute(method: "GET", path: "/api/media/:id/file") { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id/file") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            let media = MediaLibraryManager.shared
            let fm = FileManager.default

            // Find file URL
            let fileURL: URL? = media.photoURL(for: fileName) ?? media.videoURL(for: fileName)
            guard let url = fileURL, fm.fileExists(atPath: url.path) else {
                return HTTPResponse.error("File not found or archived", status: 404)
            }

            let contentType = mimeType(for: fileName)
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let totalSize = (attrs?[.size] as? Int64) ?? 0

            // Parse Range header
            if let rangeHeader = request.rangeHeader, rangeHeader.hasPrefix("bytes=") {
                guard let parsed = APIMediaHandler.parseRange(rangeHeader, totalSize: totalSize) else {
                    return HTTPResponse.rangeNotSatisfiable(totalSize: totalSize)
                }
                let rangeStart = parsed.start
                let rangeEnd = parsed.end

                // Read the requested range using FileHandle
                let length = Int(rangeEnd - rangeStart + 1)
                guard length > 0 else {
                    return HTTPResponse.rangeNotSatisfiable(totalSize: totalSize)
                }

                guard let fh = try? FileHandle(forReadingFrom: url) else {
                    return HTTPResponse.error("Failed to read file", status: 500)
                }
                fh.seek(toFileOffset: UInt64(rangeStart))
                let data = fh.readData(ofLength: length)
                fh.closeFile()

                return HTTPResponse.partialContent(
                    data,
                    contentType: contentType,
                    totalSize: totalSize,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                )
            }

            // No Range header — serve whole file for small files, reject large files
            let maxBytes: Int64 = 200 * 1024 * 1024
            if totalSize > maxBytes {
                ActivityLogManager.shared.warning(.webServer, "Rejected large file download without Range: \(fileName) (\(totalSize) bytes)")
                return HTTPResponse.error("File too large for non-Range request (\(totalSize / 1024 / 1024)MB). Use Range header.", status: 413)
            }

            guard let data = try? Data(contentsOf: url) else {
                return HTTPResponse.error("Failed to read file", status: 500)
            }

            return HTTPResponse(
                status: 200, statusText: "OK",
                headers: [
                    "Content-Type": contentType,
                    "Content-Length": "\(data.count)",
                    "Accept-Ranges": "bytes",
                    "Content-Disposition": "attachment; filename=\"\(fileName)\""
                ],
                body: data
            )
        }

        // Get thumbnail
        router.addRoute(method: "GET", path: "/api/media/:id/thumbnail") { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id/thumbnail") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            let media = MediaLibraryManager.shared
            if let url = media.thumbnailURL(for: fileName), let data = try? Data(contentsOf: url) {
                return HTTPResponse.data(data, contentType: "image/jpeg")
            }
            // Fallback: generate thumbnail from photo
            if let url = media.photoURL(for: fileName) {
                if let thumbData = ThumbnailGenerator.shared.generateThumbnailJPEG(from: url) {
                    // Save for next time
                    let thumbURL = media.thumbnailsDirectory.appendingPathComponent(fileName)
                    try? thumbData.write(to: thumbURL)
                    MediaIndexStore.shared.setThumbnailPath(thumbURL.path, for: fileName)
                    return HTTPResponse.data(thumbData, contentType: "image/jpeg")
                }
            }
            // Fallback: generate thumbnail from video
            if let url = media.videoURL(for: fileName) {
                if let thumbData = ThumbnailGenerator.shared.generateVideoThumbnailJPEG(from: url) {
                    let thumbURL = media.thumbnailsDirectory.appendingPathComponent(fileName)
                    try? thumbData.write(to: thumbURL)
                    MediaIndexStore.shared.setThumbnailPath(thumbURL.path, for: fileName)
                    return HTTPResponse.data(thumbData, contentType: "image/jpeg")
                }
            }
            return HTTPResponse.error("Thumbnail not available", status: 404)
        }

        // Delete media (admin-only)
        router.addRoute(method: "DELETE", path: "/api/media/:id", requiredRole: .admin) { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            let media = MediaLibraryManager.shared
            let index = MediaIndexStore.shared
            let entry = index.entry(for: fileName)

            // If archived, warn but allow
            if !entry.localOriginalExists && entry.verified {
                index.removeEntry(for: fileName)
                ActivityLogManager.shared.info(.media, "Removed archived entry: \(fileName)")
                AuditLogManager.shared.log(
                    method: "DELETE", path: "/api/media/:id", status: 200,
                    remoteAddress: request.remoteAddress ?? "unknown",
                    user: request.sessionUsername,
                    detail: "delete media: \(fileName)"
                )
                return HTTPResponse.json(["status": "removed", "archived": true])
            }

            let deleted = media.deleteItem(fileName: fileName)
            if deleted {
                ActivityLogManager.shared.info(.media, "Deleted: \(fileName)")
                AuditLogManager.shared.log(
                    method: "DELETE", path: "/api/media/:id", status: 200,
                    remoteAddress: request.remoteAddress ?? "unknown",
                    user: request.sessionUsername,
                    detail: "delete media: \(fileName)"
                )
                return HTTPResponse.json(["status": "deleted"])
            }
            return HTTPResponse.error("File not found", status: 404)
        }

        // Upload now (enqueue)
        router.addRoute(method: "POST", path: "/api/media/:id/upload", requiredRole: .operatorRole) { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id/upload") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            guard StorageManager.shared.activeProvider != nil else {
                return HTTPResponse.error("No storage provider configured", status: 400)
            }
            UploadQueueManager.shared.enqueue(fileName: fileName)
            AuditLogManager.shared.log(
                method: "POST", path: "/api/media/:id/upload", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "upload now: \(fileName)"
            )
            return HTTPResponse.json(["status": "queued", "fileName": fileName])
        }

        // Set or toggle favorite (operator+)
        router.addRoute(method: "POST", path: "/api/media/:id/favorite", requiredRole: .operatorRole) { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id/favorite") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            // Support explicit set via body {"isFavorite": true/false}, fallback to toggle
            if let body = request.body,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let favorite = json["isFavorite"] as? Bool {
                MediaIndexStore.shared.setFavorite(favorite, for: fileName)
            } else {
                MediaIndexStore.shared.toggleFavorite(fileName)
            }
            let isFav = MediaIndexStore.shared.isFavorite(fileName)
            AuditLogManager.shared.log(
                method: "POST", path: "/api/media/:id/favorite", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "favorite \(fileName): \(isFav)"
            )
            return HTTPResponse.json(["isFavorite": isFav])
        }

        // Set or toggle protect (operator+)
        router.addRoute(method: "POST", path: "/api/media/:id/protect", requiredRole: .operatorRole) { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id/protect") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            // Support explicit set via body {"protected": true/false}, fallback to toggle
            let newValue: Bool
            if let body = request.body,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let protected = json["protected"] as? Bool {
                newValue = protected
            } else {
                let current = MediaIndexStore.shared.entry(for: fileName).protected
                newValue = !current
            }
            MediaIndexStore.shared.setProtected(newValue, for: fileName)
            AuditLogManager.shared.log(
                method: "POST", path: "/api/media/:id/protect", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "protect \(fileName): \(newValue)"
            )
            return HTTPResponse.json(["protected": newValue])
        }
    }

    /// Parse Range header value. Supports bytes=start-end, bytes=start-, bytes=-suffix.
    private static func parseRange(_ header: String, totalSize: Int64) -> (start: Int64, end: Int64)? {
        guard header.hasPrefix("bytes="), totalSize > 0 else { return nil }
        let rangeSpec = String(header.dropFirst(6))
        let parts = rangeSpec.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let startStr = String(parts[0]).trimmingCharacters(in: .whitespaces)
        let endStr = String(parts[1]).trimmingCharacters(in: .whitespaces)

        if startStr.isEmpty {
            // Suffix range: bytes=-500
            guard let suffix = Int64(endStr), suffix > 0 else { return nil }
            return (max(0, totalSize - suffix), totalSize - 1)
        }

        guard let start = Int64(startStr), start >= 0, start < totalSize else { return nil }

        if endStr.isEmpty {
            // Open range: bytes=500-
            return (start, totalSize - 1)
        }

        guard let end = Int64(endStr), end >= start else { return nil }
        return (start, min(end, totalSize - 1))
    }

    /// Sanitize fileName to prevent path traversal
    private static func sanitizeFileName(_ name: String) -> String {
        let decoded = name.removingPercentEncoding ?? name
        let safe = (decoded as NSString).lastPathComponent
        if safe.contains("..") || safe.isEmpty { return "" }
        return safe
    }

    /// MIME type from file extension
    private static func mimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "heic": return "image/heic"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "m4v": return "video/x-m4v"
        case "avi": return "video/x-msvideo"
        default: return "application/octet-stream"
        }
    }
}
