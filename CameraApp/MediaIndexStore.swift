import Foundation

enum MediaSource: String, Codable {
    case manual
    case automation
    case motion
    case imported
}

struct MediaIndexEntry: Codable {
    var isFavorite: Bool = false
    var source: MediaSource = .manual
    var telegramSent: Bool = false
    var tags: [String] = []
}

final class MediaIndexStore: ObservableObject {
    static let shared = MediaIndexStore()

    @Published private(set) var entries: [String: MediaIndexEntry] = [:]  // keyed by fileName

    private var fileURL: URL {
        MediaLibraryManager.shared.baseDirectory.appendingPathComponent("media_index.json")
    }

    private init() {
        load()
    }

    // MARK: - Access

    func entry(for fileName: String) -> MediaIndexEntry {
        entries[fileName] ?? MediaIndexEntry()
    }

    func isFavorite(_ fileName: String) -> Bool {
        entries[fileName]?.isFavorite ?? false
    }

    func toggleFavorite(_ fileName: String) {
        var e = entry(for: fileName)
        e.isFavorite.toggle()
        entries[fileName] = e
        persist()
    }

    func setSource(_ source: MediaSource, for fileName: String) {
        var e = entry(for: fileName)
        e.source = source
        entries[fileName] = e
        persist()
    }

    func markTelegramSent(_ fileName: String) {
        var e = entry(for: fileName)
        e.telegramSent = true
        entries[fileName] = e
        persist()
    }

    func addTag(_ tag: String, to fileName: String) {
        var e = entry(for: fileName)
        if !e.tags.contains(tag) {
            e.tags.append(tag)
            entries[fileName] = e
            persist()
        }
    }

    func removeTag(_ tag: String, from fileName: String) {
        var e = entry(for: fileName)
        e.tags.removeAll { $0 == tag }
        entries[fileName] = e
        persist()
    }

    // MARK: - Queries

    var favorites: [String] {
        entries.filter { $0.value.isFavorite }.map { $0.key }
    }

    func items(withSource source: MediaSource) -> [String] {
        entries.filter { $0.value.source == source }.map { $0.key }
    }

    func telegramSentItems() -> [String] {
        entries.filter { $0.value.telegramSent }.map { $0.key }
    }

    // MARK: - Cleanup

    func removeEntry(for fileName: String) {
        entries.removeValue(forKey: fileName)
        persist()
    }

    func removeEntries(for fileNames: [String]) {
        for name in fileNames {
            entries.removeValue(forKey: name)
        }
        persist()
    }

    /// Reconcile index with actual files on disk.
    /// Removes orphan index entries and creates default entries for unindexed files.
    func reconcileWithLibrary(photoFileNames: Set<String>, videoFileNames: Set<String>) {
        let allFileNames = photoFileNames.union(videoFileNames)
        var orphansRemoved = 0
        var missingAdded = 0

        // Remove orphan entries (index exists but file doesn't)
        let orphans = entries.keys.filter { !allFileNames.contains($0) }
        for orphan in orphans {
            entries.removeValue(forKey: orphan)
            orphansRemoved += 1
        }

        // Add missing entries (file exists but no index)
        for fileName in allFileNames {
            if entries[fileName] == nil {
                let source: MediaSource = fileName.hasPrefix("Photo_") ? .manual : .manual
                entries[fileName] = MediaIndexEntry(source: source)
                missingAdded += 1
            }
        }

        if orphansRemoved > 0 || missingAdded > 0 {
            persist()
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
        entries = (try? JSONDecoder().decode([String: MediaIndexEntry].self, from: data)) ?? [:]
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        _ = MediaLibraryManager.shared.writeAtomically(data, to: fileURL)
    }
}
