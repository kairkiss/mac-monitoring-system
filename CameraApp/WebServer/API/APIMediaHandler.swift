import Foundation

struct APIMediaHandler {
    static func register(router: WebRouter) {
        // List media (paginated, filtered)
        router.addRoute(method: "GET", path: "/api/media") { request in
            let media = MediaLibraryManager.shared
            let index = MediaIndexStore.shared

            let page = Int(request.queryParameters["page"] ?? "1") ?? 1
            let perPage = min(Int(request.queryParameters["perPage"] ?? "20") ?? 20, 100)
            let type = request.queryParameters["type"] // "photo" or "video"
            let source = request.queryParameters["source"]
            let favorite = request.queryParameters["favorite"]

            var items: [[String: Any]] = []

            let photos = media.photoFileNames
            let videos = media.videoFileNames

            var allFiles: [(String, String)] = [] // (fileName, type)
            if type == nil || type == "photo" {
                allFiles.append(contentsOf: photos.map { ($0, "photo") })
            }
            if type == nil || type == "video" {
                allFiles.append(contentsOf: videos.map { ($0, "video") })
            }

            // Apply filters
            var filtered = allFiles
            if let source = source, let src = MediaSource(rawValue: source) {
                filtered = filtered.filter { index.entry(for: $0.0).source == src }
            }
            if favorite == "true" {
                filtered = filtered.filter { index.isFavorite($0.0) }
            }

            // Sort by date (newest first)
            filtered.sort { $0.0 > $1.0 }

            let total = filtered.count
            let start = (page - 1) * perPage
            let end = min(start + perPage, total)

            if start < total {
                for (fileName, mediaType) in filtered[start..<end] {
                    let entry = index.entry(for: fileName)
                    items.append([
                        "fileName": fileName,
                        "type": mediaType,
                        "isFavorite": entry.isFavorite,
                        "source": entry.source.rawValue,
                        "uploadStatus": entry.uploadStatus.rawValue,
                        "verified": entry.verified
                    ] as [String: Any])
                }
            }

            return HTTPResponse.json([
                "items": items,
                "total": total,
                "page": page,
                "perPage": perPage,
                "totalPages": (total + perPage - 1) / perPage
            ] as [String: Any])
        }

        // Get media file
        router.addRoute(method: "GET", path: "/api/media/:id/file") { request in
            let fileName = router.extractParam("id", from: request, pattern: "/api/media/:id/file") ?? ""
            let media = MediaLibraryManager.shared

            if let url = media.photoURL(for: fileName) {
                guard let data = try? Data(contentsOf: url) else {
                    return HTTPResponse.error("File not found", status: 404)
                }
                return HTTPResponse.data(data, contentType: "image/jpeg")
            }
            if let url = media.videoURL(for: fileName) {
                guard let data = try? Data(contentsOf: url) else {
                    return HTTPResponse.error("File not found", status: 404)
                }
                return HTTPResponse.data(data, contentType: "video/mp4")
            }
            return HTTPResponse.error("File not found", status: 404)
        }

        // Get thumbnail
        router.addRoute(method: "GET", path: "/api/media/:id/thumbnail") { request in
            let fileName = router.extractParam("id", from: request, pattern: "/api/media/:id/thumbnail") ?? ""
            let media = MediaLibraryManager.shared

            if let url = media.thumbnailURL(for: fileName), let data = try? Data(contentsOf: url) {
                return HTTPResponse.data(data, contentType: "image/jpeg")
            }
            // Fallback to full photo
            if let url = media.photoURL(for: fileName), let data = try? Data(contentsOf: url) {
                return HTTPResponse.data(data, contentType: "image/jpeg")
            }
            return HTTPResponse.error("Thumbnail not found", status: 404)
        }

        // Delete media
        router.addRoute(method: "DELETE", path: "/api/media/:id") { request in
            let fileName = router.extractParam("id", from: request, pattern: "/api/media/:id") ?? ""
            let media = MediaLibraryManager.shared

            if media.photoURL(for: fileName) != nil {
                _ = media.deleteItem(fileName: fileName)
                return HTTPResponse.ok()
            }
            if media.videoURL(for: fileName) != nil {
                _ = media.deleteItem(fileName: fileName)
                return HTTPResponse.ok()
            }
            return HTTPResponse.error("File not found", status: 404)
        }

        // Toggle favorite
        router.addRoute(method: "POST", path: "/api/media/:id/favorite") { request in
            let fileName = router.extractParam("id", from: request, pattern: "/api/media/:id/favorite") ?? ""
            MediaIndexStore.shared.toggleFavorite(fileName)
            let isFav = MediaIndexStore.shared.isFavorite(fileName)
            return HTTPResponse.json(["isFavorite": isFav])
        }
    }
}
