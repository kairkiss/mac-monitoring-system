import Foundation
import AppKit
import AVFoundation

enum MediaType: String, Codable {
    case photo
    case video
}

struct MediaItem: Identifiable, Codable, Hashable {
    let id: UUID
    let fileName: String
    let fileType: MediaType
    let createdAt: Date
    let fileSize: Int64
}

final class MediaLibraryManager: ObservableObject {
    static let shared = MediaLibraryManager()

    @Published var photos: [MediaItem] = []
    @Published var videos: [MediaItem] = []

    private let thumbnailCache = NSCache<NSString, NSImage>()

    var baseDirectory: URL {
        let custom = SettingsStore.shared.customStoragePath
        if !custom.isEmpty {
            return URL(fileURLWithPath: custom).appendingPathComponent("CameraApp")
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CameraApp")
    }

    var photosDirectory: URL { baseDirectory.appendingPathComponent("Photos") }
    var videosDirectory: URL { baseDirectory.appendingPathComponent("Videos") }

    var totalPhotoCount: Int { photos.count }
    var totalVideoCount: Int { videos.count }
    var totalStorageBytes: Int64 {
        photos.reduce(0) { $0 + $1.fileSize } + videos.reduce(0) { $0 + $1.fileSize }
    }

    private init() {
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        ensureDirectoriesExist()
        NotificationCenter.default.addObserver(
            self, selector: #selector(didReceiveMemoryWarning),
            name: NSApplication.didResignActiveNotification, object: nil
        )
    }

    @objc private func didReceiveMemoryWarning() {
        thumbnailCache.removeAllObjects()
    }

    func ensureDirectoriesExist() {
        let fm = FileManager.default
        for dir in [baseDirectory, photosDirectory, videosDirectory] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func scanLibrary() {
        photos = scanDirectory(photosDirectory, type: .photo)
        videos = scanDirectory(videosDirectory, type: .video)
    }

    func registerPhoto(fileName: String, fileSize: Int64) {
        let item = MediaItem(id: UUID(), fileName: fileName, fileType: .photo, createdAt: Date(), fileSize: fileSize)
        DispatchQueue.main.async { [weak self] in
            self?.photos.insert(item, at: 0)
        }
    }

    func registerVideo(fileName: String, fileSize: Int64) {
        let item = MediaItem(id: UUID(), fileName: fileName, fileType: .video, createdAt: Date(), fileSize: fileSize)
        DispatchQueue.main.async { [weak self] in
            self?.videos.insert(item, at: 0)
        }
    }

    func savePhotoData(_ data: Data) -> URL? {
        let fileName = "Photo_\(timestampString()).jpg"
        let url = photosDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            let item = MediaItem(
                id: UUID(),
                fileName: fileName,
                fileType: .photo,
                createdAt: Date(),
                fileSize: Int64(data.count)
            )
            DispatchQueue.main.async { [weak self] in
                self?.photos.insert(item, at: 0)
            }
            return url
        } catch {
            return nil
        }
    }

    func saveVideo(at sourceURL: URL) -> URL? {
        let fileName = sourceURL.lastPathComponent
        let destURL = videosDirectory.appendingPathComponent(fileName)
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.moveItem(at: sourceURL, to: destURL)
            let attrs = try? fm.attributesOfItem(atPath: destURL.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            let item = MediaItem(
                id: UUID(),
                fileName: fileName,
                fileType: .video,
                createdAt: Date(),
                fileSize: size
            )
            DispatchQueue.main.async { [weak self] in
                self?.videos.insert(item, at: 0)
            }
            return destURL
        } catch {
            return nil
        }
    }

    func deleteItem(_ item: MediaItem) {
        let url = fileURL(for: item)
        try? FileManager.default.removeItem(at: url)
        let cacheKey = "\(item.id.uuidString)_thumb" as NSString
        thumbnailCache.removeObject(forKey: cacheKey)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch item.fileType {
            case .photo: self.photos.removeAll { $0.id == item.id }
            case .video: self.videos.removeAll { $0.id == item.id }
            }
        }
    }

    func cleanOldFiles(keepDays: Int) -> Int {
        guard keepDays > 0 else { return 0 }
        let cutoff = Date().addingTimeInterval(TimeInterval(-keepDays * 86400))
        var count = 0

        let oldPhotos = photos.filter { $0.createdAt < cutoff }
        for item in oldPhotos {
            let url = fileURL(for: item)
            try? FileManager.default.removeItem(at: url)
            let cacheKey = "\(item.id.uuidString)_thumb" as NSString
            thumbnailCache.removeObject(forKey: cacheKey)
            count += 1
        }
        photos.removeAll { $0.createdAt < cutoff }

        let oldVideos = videos.filter { $0.createdAt < cutoff }
        for item in oldVideos {
            let url = fileURL(for: item)
            try? FileManager.default.removeItem(at: url)
            count += 1
        }
        videos.removeAll { $0.createdAt < cutoff }

        return count
    }

    func fileURL(for item: MediaItem) -> URL {
        let dir = item.fileType == .photo ? photosDirectory : videosDirectory
        return dir.appendingPathComponent(item.fileName)
    }

    func revealInFinder(_ item: MediaItem) {
        let url = fileURL(for: item)
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }

    func thumbnail(for item: MediaItem, maxSize: CGSize) -> NSImage? {
        let cacheKey = "\(item.id.uuidString)_\(Int(maxSize.width))x\(Int(maxSize.height))" as NSString
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        let url = fileURL(for: item)
        let image: NSImage?
        switch item.fileType {
        case .photo:
            guard let img = NSImage(contentsOf: url) else { return nil }
            image = resizeImage(img, to: maxSize)
        case .video:
            image = videoThumbnail(for: url, maxSize: maxSize)
        }

        if let result = image {
            let cost = Int(result.size.width * result.size.height * 4)
            thumbnailCache.setObject(result, forKey: cacheKey, cost: cost)
        }
        return image
    }

    // MARK: - Private

    private func scanDirectory(_ directory: URL, type: MediaType) -> [MediaItem] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return files.compactMap { fileURL -> MediaItem? in
            let ext = fileURL.pathExtension.lowercased()
            let validExts: Set<String> = type == .photo ? ["jpg", "jpeg", "png", "tiff", "heic"] : ["mov", "mp4", "m4v"]
            guard validExts.contains(ext) else { return nil }

            let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            let created = resourceValues?.creationDate ?? Date()
            let size = Int64(resourceValues?.fileSize ?? 0)

            return MediaItem(
                id: UUID(),
                fileName: fileURL.lastPathComponent,
                fileType: type,
                createdAt: created,
                fileSize: size
            )
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func resizeImage(_ image: NSImage, to maxSize: CGSize) -> NSImage {
        let ratio = min(maxSize.width / image.size.width, maxSize.height / image.size.height)
        guard ratio < 1 else { return image }
        let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: .zero, operation: .sourceOver, fraction: 1.0)
        thumbnail.unlockFocus()
        return thumbnail
    }

    private func videoThumbnail(for url: URL, maxSize: CGSize) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        let time = CMTime(value: 0, timescale: 1)
        var actualTime = CMTime.zero
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: &actualTime) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
