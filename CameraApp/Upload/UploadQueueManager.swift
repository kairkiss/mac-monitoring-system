import Foundation

final class UploadQueueManager: ObservableObject {
    static let shared = UploadQueueManager()

    @Published private(set) var isProcessing = false
    @Published private(set) var isPaused = false

    private let store = UploadQueueStore.shared

    var jobs: [UploadJob] { store.jobs }
    private let settings = SettingsStore.shared
    private var processingTimer: Timer?

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

        if isProcessing {
            processNext()
        }
    }

    func retry(jobID: String) {
        guard var job = store.jobs.first(where: { $0.id == jobID }) else { return }
        job.status = .pending
        job.lastError = nil
        store.updateJob(job)
        processNext()
    }

    func cancel(jobID: String) {
        guard var job = store.jobs.first(where: { $0.id == jobID }) else { return }
        job.status = .cancelled
        store.updateJob(job)
        MediaIndexStore.shared.setUploadStatus(.notQueued, for: job.fileName)
    }

    func retryAllFailed() {
        for var job in store.jobs where job.status == .failed {
            job.status = .pending
            job.lastError = nil
            store.updateJob(job)
        }
        processNext()
    }

    func pauseAll() {
        isPaused = true
        stopProcessing()
    }

    func resumeAll() {
        isPaused = false
        startProcessing()
    }

    private func processNext() {
        guard let provider = StorageManager.shared.activeProvider else { return }
        let maxConcurrent = settings.uploadMaxConcurrent
        let activeCount = store.activeJobs().count
        guard activeCount < maxConcurrent else { return }

        guard var job = store.pendingJobs().first else { return }
        job.status = .uploading
        job.startedAt = Date()
        store.updateJob(job)
        MediaIndexStore.shared.setUploadStatus(.uploading, for: job.fileName)

        Task {
            do {
                let localURL = URL(fileURLWithPath: job.localPath)
                let result = try await provider.upload(fileAt: localURL, remotePath: job.remotePath) { progress in
                    var updated = job
                    updated.progress = progress
                    self.store.updateJob(updated)
                }

                var completed = job
                completed.status = .completed
                completed.completedAt = Date()
                completed.progress = 1.0
                self.store.updateJob(completed)

                MediaIndexStore.shared.markUploadVerified(
                    job.fileName,
                    remoteFileID: result.remoteFileID,
                    remoteURL: result.remoteURL
                )
                ActivityLogManager.shared.success(.upload, "Uploaded \(job.fileName)")

                await MainActor.run { self.processNext() }
            } catch {
                var failed = job
                failed.attempts += 1
                failed.lastError = error.localizedDescription

                if failed.attempts < failed.maxRetries {
                    failed.status = .retrying
                    ActivityLogManager.shared.warning(.upload, "Retrying \(job.fileName) (attempt \(failed.attempts))")
                } else {
                    failed.status = .failed
                    ActivityLogManager.shared.error(.upload, "Upload failed: \(job.fileName)", detail: error.localizedDescription)
                }

                self.store.updateJob(failed)
                MediaIndexStore.shared.setUploadStatus(.failed, for: job.fileName)

                await MainActor.run { self.processNext() }
            }
        }
    }
}
