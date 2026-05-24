import Foundation

enum MediaSource: String, Codable {
    case manual
    case automation
    case motion
    case imported
    case event
}

enum UploadEntryStatus: String, Codable {
    case notQueued
    case queued
    case uploading
    case completed
    case verified
    case failed
    case localDeleted
    case waitingForProvider
}

struct MediaIndexEntry: Codable {
    var isFavorite: Bool = false
    var source: MediaSource = .manual
    var telegramSent: Bool = false
    var tags: [String] = []

    // v2.0.0 upload tracking
    var uploadStatus: UploadEntryStatus = .notQueued
    var uploadProvider: String?  // rawValue of StorageProviderType
    var providerType: String?   // explicit provider type for lookups
    var uploadRemotePath: String?
    var uploadDate: Date?
    var uploadJobID: String?
    var uploadAttempts: Int = 0
    var uploadLastError: String?
    var remoteFileID: String?
    var remoteURL: String?
    var verified: Bool = false
    var verifiedAt: Date?
    var protected: Bool = false
    var localOriginalExists: Bool = true
    var localDeletedAt: Date?
    var thumbnailPath: String?
    var cameraName: String?
    var duration: TimeInterval?
    var fileSize: Int64 = 0
}

final class MediaIndexStore: ObservableObject {
    static let shared = MediaIndexStore()

    @Published private(set) var entries: [String: MediaIndexEntry] = [:]  // keyed by fileName
    private let queue = DispatchQueue(label: "media-index-store", qos: .userInitiated)

    private var fileURL: URL {
        MediaLibraryManager.shared.baseDirectory.appendingPathComponent("media_index.json")
    }

    private init() {
        load()
    }

    // MARK: - Access

    func entry(for fileName: String) -> MediaIndexEntry {
        queue.sync { entries[fileName] ?? MediaIndexEntry() }
    }

    func isFavorite(_ fileName: String) -> Bool {
        queue.sync { entries[fileName]?.isFavorite ?? false }
    }

    func toggleFavorite(_ fileName: String) {
        queue.sync {
            var e = entries[fileName] ?? MediaIndexEntry()
            e.isFavorite.toggle()
            entries[fileName] = e
        }
        notifyAndPersist()
    }

    func setSource(_ source: MediaSource, for fileName: String) {
        queue.sync {
            var e = entries[fileName] ?? MediaIndexEntry()
            e.source = source
            entries[fileName] = e
        }
        notifyAndPersist()
    }

    func markTelegramSent(_ fileName: String) {
        queue.sync {
            var e = entries[fileName] ?? MediaIndexEntry()
            e.telegramSent = true
            entries[fileName] = e
        }
        notifyAndPersist()
    }

    func addTag(_ tag: String, to fileName: String) {
        queue.sync {
            var e = entries[fileName] ?? MediaIndexEntry()
            if !e.tags.contains(tag) {
                e.tags.append(tag)
                entries[fileName] = e
            }
        }
        notifyAndPersist()
    }

    func removeTag(_ tag: String, from fileName: String) {
        queue.sync {
            var e = entries[fileName] ?? MediaIndexEntry()
            e.tags.removeAll { $0 == tag }
            entries[fileName] = e
        }
        notifyAndPersist()
    }

    // MARK: - Queries

    var favorites: [String] {
        queue.sync { entries.filter { $0.value.isFavorite }.map { $0.key } }
    }

    func items(withSource source: MediaSource) -> [String] {
        queue.sync { entries.filter { $0.value.source == source }.map { $0.key } }
    }

    func telegramSentItems() -> [String] {
        queue.sync { entries.filter { $0.value.telegramSent }.map { $0.key } }
    }

    // MARK: - Upload Tracking

    func setUploadStatus(_ status: UploadEntryStatus, for fileName: String, provider: String? = nil, remotePath: String? = nil, jobID: String? = nil) {
        queue.sync {
            var e = entries[fileName] ?? MediaIndexEntry()
            e.uploadStatus = status
            if let provider { e.uploadProvider = provider }
            if let remotePath { e.uploadRemotePath = remotePath }
            if let jobID { e.uploadJobID = jobID }
            if status == .completed || status == .verified {
                e.uploadDate = Date()
            }
            entries[fileName] = e
        }
        notifyAndPersist()
    }

    func markUploadVerified(_ fileName: String, remoteFileID: String?, remoteURL: String?, providerType: String? = nil, remotePath: String? = nil) {
        queue.sync {
            var e = entries[fileName] ?? MediaIndexEntry()
            e.uploadStatus = .verified
            e.verified = true
            e.verifiedAt = Date()
            e.uploadDate = Date()
            if let remoteFileID { e.remoteFileID = remoteFileID }
            if let remoteURL { e.remoteURL = remoteURL }
            if let providerType { e.providerType = providerType }
            if let providerType { e.uploadProvider = providerType }
            if let remotePath { e.uploadRemotePath = remotePath }
            entries[fileName] = e
        }
        notifyAndPersist()
    }

    func markLocalDeleted(_ fileName: String) {
        queue.sync {
            var e = entries[fileName] ?? MediaIndexEntry()
            e.localOriginalExists = false
            e.localDeletedAt = Date()
            e.uploadStatus = .localDeleted
            entries[fileName] = e
        }
        notifyAndPersist()
    }

    func setProtected(_ protected: Bool, for fileName: String) {
        queue.sync {
            var e = entries[fileName] ?? MediaIndexEntry()
            e.protected = protected
            entries[fileName] = e
        }
        notifyAndPersist()
    }

    func setThumbnailPath(_ path: String, for fileName: String) {
        queue.sync {
            var e = entries[fileName] ?? MediaIndexEntry()
            e.thumbnailPath = path
            entries[fileName] = e
        }
        notifyAndPersist()
    }

    func pendingUploadItems() -> [String] {
        queue.sync { entries.filter { $0.value.uploadStatus == .queued || $0.value.uploadStatus == .uploading }.map { $0.key } }
    }

    func verifiedItems() -> [String] {
        queue.sync { entries.filter { $0.value.verified }.map { $0.key } }
    }

    func localDeletedItems() -> [String] {
        queue.sync { entries.filter { !$0.value.localOriginalExists }.map { $0.key } }
    }

    // MARK: - Cleanup

    func removeEntry(for fileName: String) {
        queue.sync { _ = entries.removeValue(forKey: fileName) }
        notifyAndPersist()
    }

    func removeEntries(for fileNames: [String]) {
        queue.sync {
            for name in fileNames {
                entries.removeValue(forKey: name)
            }
        }
        notifyAndPersist()
    }

    /// Reconcile index with actual files on disk.
    /// Removes orphan index entries but preserves archived/verified entries.
    func reconcileWithLibrary(photoFileNames: Set<String>, videoFileNames: Set<String>) {
        let allFileNames = photoFileNames.union(videoFileNames)
        var orphansRemoved = 0
        var missingAdded = 0

        queue.sync {
            let orphans = entries.keys.filter { !allFileNames.contains($0) }
            for orphan in orphans {
                let entry = entries[orphan]!
                if entry.verified && !entry.localOriginalExists { continue }
                if entry.protected { continue }
                entries.removeValue(forKey: orphan)
                orphansRemoved += 1
            }

            for fileName in allFileNames {
                if entries[fileName] == nil {
                    let source: MediaSource = fileName.hasPrefix("Photo_") ? .manual : .manual
                    entries[fileName] = MediaIndexEntry(source: source)
                    missingAdded += 1
                }
            }
        }

        if orphansRemoved > 0 || missingAdded > 0 {
            notifyAndPersist()
            if orphansRemoved > 0 {
                ActivityLogManager.shared.info(.media, "Cleaned \(orphansRemoved) orphan index entries")
            }
            if missingAdded > 0 {
                ActivityLogManager.shared.info(.media, "Added \(missingAdded) missing index entries")
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoded = (try? JSONDecoder().decode([String: MediaIndexEntry].self, from: data)) ?? [:]
        entries = decoded
    }

    private func notifyAndPersist() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.objectWillChange.send()
        }
        persist()
    }

    private func persist() {
        let snapshot = queue.sync { entries }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        _ = MediaLibraryManager.shared.writeAtomically(data, to: fileURL)
    }
}
