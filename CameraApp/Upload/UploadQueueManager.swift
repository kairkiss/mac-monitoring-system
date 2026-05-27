import Foundation

final class UploadQueueManager: ObservableObject {
    static let shared = UploadQueueManager()

    @Published private(set) var isProcessing = false
    @Published private(set) var isPaused = false

    private let store = UploadQueueStore.shared

    var jobs: [UploadJob] { store.jobs }
    private let settings = SettingsStore.shared
    private var processingTimer: Timer?
    private var processLoopActive = false

    private init() {}

    func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true
        processingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.processNext()
        }
        processNext()
    }

    func stopProcessing() {
        isProcessing = false
        processingTimer?.invalidate()
        processingTimer = nil
    }

    func enqueue(fileName: String) {
        guard let provider = StorageManager.shared.activeProvider else { return }
        let media = MediaLibraryManager.shared
        let localURL: URL?
        if media.photoFileNames.contains(fileName) {
            localURL = media.photoURL(for: fileName)
        } else if media.videoFileNames.contains(fileName) {
            localURL = media.videoURL(for: fileName)
        } else {
            localURL = nil
        }
        guard let localURL else { return }

        let remotePath = "\(provider.type.rawValue)/\(fileName)"
        var job = UploadJob(
            fileName: fileName,
            localPath: localURL.path,
            remotePath: remotePath,
            providerType: provider.type.rawValue
        )
        job.maxRetries = settings.uploadMaxRetries
        store.enqueue(job)
        MediaIndexStore.shared.setUploadStatus(.queued, for: fileName, provider: provider.type.rawValue, remotePath: remotePath, jobID: job.id)
        ActivityLogManager.shared.info(.upload, "Queued \(fileName) for upload")

        if isProcessing && !isPaused {
            processNext()
        }
    }

    func retry(jobID: String) {
        guard var job = store.jobs.first(where: { $0.id == jobID }) else { return }
        // If no provider available, mark as waiting instead of pending
        if StorageManager.shared.activeProvider == nil {
            job.status = .waitingForProvider
            job.lastError = Strings.uploadWaitingForProvider
            store.updateJob(job)
            MediaIndexStore.shared.setUploadStatus(.waitingForProvider, for: job.fileName)
            return
        }
        job.status = .pending
        job.lastError = nil
        job.errorClass = nil
        job.nextRetryAt = nil
        job.retryDelaySeconds = nil
        store.updateJob(job)
        if !isPaused { processNext() }
    }

    func cancel(jobID: String) {
        guard var job = store.jobs.first(where: { $0.id == jobID }) else { return }
        job.status = .cancelled
        store.updateJob(job)
        MediaIndexStore.shared.setUploadStatus(.notQueued, for: job.fileName)
    }

    func retryAllFailed() {
        let hasProvider = StorageManager.shared.activeProvider != nil
        let gdriveProviders: Set<String> = ["googleDrive", "google_drive", "gdrive"]
        let gdAuth = GoogleDriveAuthManager.shared

        for var job in store.jobs where job.status == .failed || job.status == .waitingForProvider {
            if !hasProvider {
                job.status = .waitingForProvider
                job.lastError = Strings.uploadWaitingForProvider
                store.updateJob(job)
                continue
            }

            // Classify the error to decide retry behavior
            let errClass = job.errorClass.flatMap { GoogleDriveAPIError(rawValue: $0) }

            switch errClass {
            case .authExpired, .notAuthenticated, .credentialsMissing:
                if gdriveProviders.contains(job.providerType) {
                    // Keep as waitingForProvider — don't blindly retry auth errors
                    if gdAuth.isAuthenticated && !gdAuth.needsReconnect {
                        // Google Drive is actually connected now, safe to retry
                        job.status = .pending
                        job.lastError = nil
                        job.errorClass = nil
                        job.nextRetryAt = nil
                        job.retryDelaySeconds = nil
                    } else {
                        job.status = .waitingForProvider
                        job.lastError = "Waiting for Google Drive reconnect"
                    }
                } else {
                    // Non-Google Drive auth error: retry
                    job.status = .pending
                    job.lastError = nil
                    job.errorClass = nil
                    job.nextRetryAt = nil
                    job.retryDelaySeconds = nil
                }
            case .quotaExceeded, .permissionDenied, .rootFolderMissing:
                // Don't blindly retry — these need user action
                // Keep as failed
                break
            default:
                // rateLimited, networkUnavailable, unknown, verificationFailed, nil → retry
                job.status = .pending
                job.lastError = nil
                job.errorClass = nil
                job.nextRetryAt = nil
                job.retryDelaySeconds = nil
            }
            store.updateJob(job)
        }
        if !isPaused && hasProvider { processNext() }
    }

    func pauseAll() {
        isPaused = true
        stopProcessing()
    }

    func resumeAll() {
        isPaused = false
        startProcessing()
    }

    /// Called when storage provider changes — transitions waiting jobs back to pending
    func reattachWaitingJobs() {
        let hasProvider = StorageManager.shared.activeProvider != nil
        guard hasProvider else { return }
        var reattached = 0
        for var job in store.jobs where job.status == .waitingForProvider {
            job.status = .pending
            job.lastError = nil
            store.updateJob(job)
            reattached += 1
        }
        if reattached > 0 {
            ActivityLogManager.shared.info(.upload, "Reattached \(reattached) waiting jobs to active provider")
            if isProcessing && !isPaused { processNext() }
        }
    }

    private func processNext() {
        guard !isPaused else { return }
        guard !processLoopActive else { return }
        processLoopActive = true

        // Check if provider is available
        guard let provider = StorageManager.shared.activeProvider else {
            // Mark pending/retrying jobs as waiting for provider
            for var job in store.pendingJobs() where job.status == .pending || job.status == .retrying {
                job.status = .waitingForProvider
                job.lastError = Strings.uploadWaitingForProvider
                store.updateJob(job)
                MediaIndexStore.shared.setUploadStatus(.waitingForProvider, for: job.fileName)
            }
            if !store.pendingJobs().isEmpty || store.jobs.contains(where: { $0.status == .waitingForProvider }) {
                ActivityLogManager.shared.warning(.upload, "Upload queue waiting: no storage provider active")
            }
            processLoopActive = false
            return
        }

        let maxConcurrent = settings.uploadMaxConcurrent
        let activeCount = store.activeJobs().count
        guard activeCount < maxConcurrent else { processLoopActive = false; return }

        guard var job = store.pendingJobs().first else { processLoopActive = false; return }
        job.status = .uploading
        job.startedAt = Date()
        store.updateJob(job)
        MediaIndexStore.shared.setUploadStatus(.uploading, for: job.fileName)

        Task {
            do {
                let localURL = URL(fileURLWithPath: job.localPath)

                // Verify local file exists before attempting upload
                guard FileManager.default.fileExists(atPath: job.localPath) else {
                    throw UploadError.localFileMissing(job.fileName)
                }

                let result = try await provider.upload(fileAt: localURL, remotePath: job.remotePath) { progress in
                    var updated = job
                    updated.progress = progress
                    self.store.updateJob(updated)
                }

                var completed = job
                completed.status = .completed
                completed.completedAt = Date()
                completed.progress = 1.0
                completed.fileSize = result.fileSize
                completed.errorClass = nil
                self.store.updateJob(completed)

                // Write full metadata to MediaIndex after verified upload
                MediaIndexStore.shared.markUploadVerified(
                    job.fileName,
                    remoteFileID: result.remoteFileID,
                    remoteURL: result.remoteURL,
                    providerType: provider.type.rawValue,
                    remotePath: result.remotePath
                )
                ActivityLogManager.shared.success(.upload, "Uploaded and verified: \(job.fileName)",
                    detail: "Size: \(result.fileSize) bytes, remote: \(result.remotePath)")

                self.processLoopActive = false
                await MainActor.run { self.processNext() }
            } catch {
                var failed = job
                failed.attempts += 1
                failed.lastError = error.localizedDescription

                // Classify the error for smarter retry behavior
                let errClass = classifyGoogleDriveError(error)
                failed.errorClass = errClass.rawValue

                // Check if this is a Google Drive job for auth-error recovery
                let gdriveProviders: Set<String> = ["googleDrive", "google_drive", "gdrive"]
                let isGdriveJob = gdriveProviders.contains(job.providerType)

                switch errClass {
                case .authExpired, .notAuthenticated, .credentialsMissing:
                    if isGdriveJob {
                        // Move to waitingForProvider — user reconnects, then retry-waiting restores
                        failed.status = .waitingForProvider
                        failed.nextRetryAt = nil
                        failed.retryDelaySeconds = nil
                        ActivityLogManager.shared.warning(.upload, "Upload waiting for Google Drive reconnect: \(job.fileName)",
                            detail: errClass.localizedDescription)
                        MediaIndexStore.shared.setUploadStatus(.waitingForProvider, for: job.fileName)
                    } else {
                        failed.status = .failed
                        ActivityLogManager.shared.error(.upload, "Upload failed (auth): \(job.fileName)",
                            detail: errClass.localizedDescription)
                    }
                case .permissionDenied:
                    // Don't retry — user needs to fix permissions
                    failed.status = .failed
                    ActivityLogManager.shared.error(.upload, "Upload failed (permission): \(job.fileName)",
                        detail: errClass.localizedDescription)
                case .quotaExceeded, .rootFolderMissing:
                    // Don't retry — quota full or root missing
                    failed.status = .failed
                    ActivityLogManager.shared.error(.upload, "Upload failed (quota): \(job.fileName)",
                        detail: errClass.localizedDescription)
                case .rateLimited:
                    // Retry with longer backoff
                    if failed.attempts < failed.maxRetries {
                        failed.status = .retrying
                        let delay = min(600, Int(pow(2.0, Double(failed.attempts))) * 10)
                        failed.retryDelaySeconds = delay
                        failed.nextRetryAt = Date().addingTimeInterval(TimeInterval(delay))
                        failed.lastAttemptAt = Date()
                        ActivityLogManager.shared.warning(.upload, "Rate limited, retrying \(job.fileName) in \(delay)s")
                    } else {
                        failed.status = .failed
                        ActivityLogManager.shared.error(.upload, "Upload failed (rate limited): \(job.fileName)")
                    }
                case .networkUnavailable:
                    // Retry with standard backoff
                    if failed.attempts < failed.maxRetries {
                        failed.status = .retrying
                        let delay = min(300, Int(pow(2.0, Double(failed.attempts))) * 5)
                        failed.retryDelaySeconds = delay
                        failed.nextRetryAt = Date().addingTimeInterval(TimeInterval(delay))
                        failed.lastAttemptAt = Date()
                        ActivityLogManager.shared.warning(.upload, "Network issue, retrying \(job.fileName) in \(delay)s")
                    } else {
                        failed.status = .failed
                        ActivityLogManager.shared.error(.upload, "Upload failed (network): \(job.fileName)")
                    }
                case .unknown, .verificationFailed:
                    // Standard retry logic
                    if failed.attempts < failed.maxRetries {
                        failed.status = .retrying
                        let delay = min(300, Int(pow(2.0, Double(failed.attempts))) * 5)
                        failed.retryDelaySeconds = delay
                        failed.nextRetryAt = Date().addingTimeInterval(TimeInterval(delay))
                        failed.lastAttemptAt = Date()
                        ActivityLogManager.shared.warning(.upload, "Retrying \(job.fileName) in \(delay)s (attempt \(failed.attempts))")
                    } else {
                        failed.status = .failed
                        ActivityLogManager.shared.error(.upload, "Upload failed: \(job.fileName)", detail: error.localizedDescription)
                    }
                }

                self.store.updateJob(failed)
                if failed.status == .waitingForProvider {
                    // Already set in switch above
                } else {
                    MediaIndexStore.shared.setUploadStatus(.failed, for: job.fileName)
                }

                self.processLoopActive = false
                await MainActor.run { self.processNext() }
            }
        }
    }
}

enum UploadError: LocalizedError {
    case localFileMissing(String)

    var errorDescription: String? {
        switch self {
        case .localFileMissing(let name): return "Local file missing: \(name)"
        }
    }
}
