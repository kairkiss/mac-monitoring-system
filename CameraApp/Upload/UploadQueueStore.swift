import Foundation

final class UploadQueueStore: ObservableObject {
    static let shared = UploadQueueStore()

    @Published private(set) var jobs: [UploadJob] = []

    private var fileURL: URL {
        MediaLibraryManager.shared.baseDirectory.appendingPathComponent("upload_queue.json")
    }

    private init() { load() }

    func enqueue(_ job: UploadJob) {
        jobs.append(job)
        persist()
    }

    func updateJob(_ job: UploadJob) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
            persist()
        }
    }

    func removeJob(id: String) {
        jobs.removeAll { $0.id == id }
        persist()
    }

    func pendingJobs() -> [UploadJob] {
        jobs.filter { $0.status == .pending || $0.status == .retrying }
    }

    func activeJobs() -> [UploadJob] {
        jobs.filter { $0.status == .uploading }
    }

    func completedJobs() -> [UploadJob] {
        jobs.filter { $0.status == .completed }
    }

    func failedJobs() -> [UploadJob] {
        jobs.filter { $0.status == .failed }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        jobs = (try? JSONDecoder().decode([UploadJob].self, from: data)) ?? []
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(jobs) else { return }
        _ = MediaLibraryManager.shared.writeAtomically(data, to: fileURL)
    }
}
