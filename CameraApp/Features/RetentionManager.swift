import Foundation

struct RetentionDryRunResult {
    let wouldDelete: Int
    let skipped: Int
    var files: [String] = []
    let reason: String?
    var skipReasons: [String: Int] = [:] // reason -> count
}

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

    func dryRun() -> RetentionDryRunResult {
        let settings = SettingsStore.shared
        guard settings.retentionDeleteAfterUpload else {
            return RetentionDryRunResult(wouldDelete: 0, skipped: 0, reason: "Retention not enabled")
        }

        let index = MediaIndexStore.shared
        let graceHours = TimeInterval(settings.retentionGracePeriodHours) * 3600
        let now = Date()
        var wouldDelete = 0
        var skipped = 0
        var files: [String] = []
        var skipReasons: [String: Int] = [:]

        func skip(_ reason: String) {
            skipped += 1
            skipReasons[reason, default: 0] += 1
        }

        for (fileName, entry) in index.entries {
            // Must be verified
            guard entry.verified, entry.uploadStatus == .verified || entry.uploadStatus == .completed else {
                if entry.uploadStatus != .notQueued && entry.uploadStatus != .localDeleted {
                    skip("notVerified")
                }
                continue
            }
            // Must have remoteFileID
            guard let remoteFileID = entry.remoteFileID, !remoteFileID.isEmpty else {
                skip("missingRemoteFileID")
                continue
            }
            // Must have remoteURL
            guard let remoteURL = entry.remoteURL, !remoteURL.isEmpty else {
                skip("missingRemoteURL")
                continue
            }
            if settings.retentionProtectFavorites && entry.isFavorite { skip("favorite"); continue }
            if entry.protected { skip("protected"); continue }
            if let uploadDate = entry.uploadDate, now.timeIntervalSince(uploadDate) < graceHours { skip("gracePeriod"); continue }
            if !entry.localOriginalExists { skip("localMissing"); continue }
            wouldDelete += 1
            files.append(fileName)
        }

        return RetentionDryRunResult(wouldDelete: wouldDelete, skipped: skipped, files: files, reason: nil, skipReasons: skipReasons)
    }

    @discardableResult
    func runCleanup() -> Int {
        let settings = SettingsStore.shared
        guard settings.retentionDeleteAfterUpload else { return 0 }

        // Safety gate: for cloud providers, verify provider is connected before deleting
        let providerType = StorageProviderType(rawValue: settings.activeStorageProviderType) ?? .none
        if providerType == .googleDrive || providerType == .webdav {
            if StorageManager.shared.activeProvider == nil {
                ActivityLogManager.shared.warning(.retention, "Retention skipped: cloud provider not connected — local originals preserved")
                return 0
            }
        }

        let index = MediaIndexStore.shared
        let media = MediaLibraryManager.shared
        let graceHours = TimeInterval(settings.retentionGracePeriodHours) * 3600
        let now = Date()
        var deleted = 0

        for (fileName, entry) in index.entries {
            // Only delete verified uploads
            guard entry.verified, entry.uploadStatus == .verified || entry.uploadStatus == .completed else { continue }

            // Never delete files currently in-flight
            guard entry.uploadStatus != .uploading, entry.uploadStatus != .queued else { continue }

            // Must have remoteFileID — don't delete if cloud metadata incomplete
            guard let remoteFileID = entry.remoteFileID, !remoteFileID.isEmpty else { continue }

            // Must have remoteURL — don't delete if we can't confirm remote exists
            guard let remoteURL = entry.remoteURL, !remoteURL.isEmpty else { continue }

            // Protect favorites if configured
            if settings.retentionProtectFavorites && entry.isFavorite { continue }

            // Protect protected items
            if entry.protected { continue }

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
        } else {
            ActivityLogManager.shared.info(.retention, "Manual cleanup: no eligible files")
        }
        return deleted
    }
}
