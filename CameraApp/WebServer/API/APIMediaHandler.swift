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
                "uploadDate": entry.uploadDate.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                "verifiedAt": entry.verifiedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
                "localDeletedAt": entry.localDeletedAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            ] as [String: Any])
        }

        // Get media file (download)
        router.addRoute(method: "GET", path: "/api/media/:id/file") { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id/file") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            let media = MediaLibraryManager.shared
            if let url = media.photoURL(for: fileName) {
                guard let data = try? Data(contentsOf: url) else {
                    return HTTPResponse.error("File not found", status: 404)
                }
                return HTTPResponse(
                    status: 200, statusText: "OK",
                    headers: [
                        "Content-Type": "image/jpeg",
                        "Content-Disposition": "attachment; filename=\"\(fileName)\""
                    ],
                    body: data
                )
            }
            if let url = media.videoURL(for: fileName) {
                guard let data = try? Data(contentsOf: url) else {
                    return HTTPResponse.error("File not found", status: 404)
                }
                return HTTPResponse(
                    status: 200, statusText: "OK",
                    headers: [
                        "Content-Type": "video/mp4",
                        "Content-Disposition": "attachment; filename=\"\(fileName)\""
                    ],
                    body: data
                )
            }
            return HTTPResponse.error("File not found or archived", status: 404)
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

        // Delete media
        router.addRoute(method: "DELETE", path: "/api/media/:id") { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            let media = MediaLibraryManager.shared
            let index = MediaIndexStore.shared
            let entry = index.entry(for: fileName)

            // If archived, warn but allow
            if !entry.localOriginalExists && entry.verified {
                index.removeEntry(for: fileName)
                ActivityLogManager.shared.info(.media, "Removed archived entry: \(fileName)")
                return HTTPResponse.json(["status": "removed", "archived": true])
            }

            let deleted = media.deleteItem(fileName: fileName)
            if deleted {
                ActivityLogManager.shared.info(.media, "Deleted: \(fileName)")
                return HTTPResponse.json(["status": "deleted"])
            }
            return HTTPResponse.error("File not found", status: 404)
        }

        // Upload now (enqueue)
        router.addRoute(method: "POST", path: "/api/media/:id/upload") { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id/upload") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            guard StorageManager.shared.activeProvider != nil else {
                return HTTPResponse.error("No storage provider configured", status: 400)
            }
            UploadQueueManager.shared.enqueue(fileName: fileName)
            return HTTPResponse.json(["status": "queued", "fileName": fileName])
        }

        // Toggle favorite
        router.addRoute(method: "POST", path: "/api/media/:id/favorite") { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id/favorite") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            MediaIndexStore.shared.toggleFavorite(fileName)
            let isFav = MediaIndexStore.shared.isFavorite(fileName)
            return HTTPResponse.json(["isFavorite": isFav])
        }

        // Toggle protect
        router.addRoute(method: "POST", path: "/api/media/:id/protect") { request in
            let fileName = sanitizeFileName(router.extractParam("id", from: request, pattern: "/api/media/:id/protect") ?? "")
            guard !fileName.isEmpty else { return HTTPResponse.error("Missing id") }

            let current = MediaIndexStore.shared.entry(for: fileName).protected
            MediaIndexStore.shared.setProtected(!current, for: fileName)
            return HTTPResponse.json(["protected": !current])
        }
    }

    /// Sanitize fileName to prevent path traversal
    private static func sanitizeFileName(_ name: String) -> String {
        let safe = (name as NSString).lastPathComponent
        if safe.contains("..") || safe.isEmpty { return "" }
        return safe
    }
}
