import Foundation

final class RetentionManager {
    static let shared = RetentionManager()

    private var timer: Timer?

    private init() {}

    func start() {
        guard SettingsStore.shared.retentionDeleteAfterUpload else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.runCleanup()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func runCleanup() {
        let settings = SettingsStore.shared
        guard settings.retentionDeleteAfterUpload else { return }

        let index = MediaIndexStore.shared
        let media = MediaLibraryManager.shared
        let graceHours = TimeInterval(settings.retentionGracePeriodHours) * 3600
        let now = Date()
        var deleted = 0

        for (fileName, entry) in index.entries {
            // Only delete verified uploads
            guard entry.verified, entry.uploadStatus == .verified || entry.uploadStatus == .completed else { continue }

            // Protect favorites if configured
            if settings.retentionProtectFavorites && entry.isFavorite { continue }

            // Protect recent files
            if let uploadDate = entry.uploadDate, now.timeIntervalSince(uploadDate) < graceHours { continue }

            // Delete local original only — preserve index entry
            if entry.localOriginalExists {
                if media.deleteLocalOriginal(fileName: fileName) {
                    index.markLocalDeleted(fileName)
                    deleted += 1
                } else {
                    ActivityLogManager.shared.warning(.retention, "Failed to delete local original: \(fileName)")
                }
            }
        }

        if deleted > 0 {
            ActivityLogManager.shared.info(.retention, "Cleaned \(deleted) local originals after verified upload")
        }
    }
}
