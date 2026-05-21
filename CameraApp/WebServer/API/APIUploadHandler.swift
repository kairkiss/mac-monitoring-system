import Foundation

struct APIUploadHandler {
    static func register(router: WebRouter) {
        // Get upload queue
        router.addRoute(method: "GET", path: "/api/upload/queue") { _ in
            let queue = UploadQueueManager.shared
            let jobs = queue.jobs.map { job in
                [
                    "id": job.id,
                    "fileName": job.fileName,
                    "status": job.status.rawValue,
                    "provider": job.providerType,
                    "attempts": job.attempts,
                    "lastError": job.lastError ?? "",
                    "createdAt": ISO8601DateFormatter().string(from: job.createdAt)
                ] as [String: Any]
            }
            return HTTPResponse.json([
                "jobs": jobs,
                "isPaused": queue.isPaused,
                "totalJobs": queue.jobs.count,
                "pendingCount": queue.jobs.filter { $0.status == .pending || $0.status == .retrying }.count,
                "failedCount": queue.jobs.filter { $0.status == .failed }.count
            ] as [String: Any])
        }

        // Retry a specific job
        router.addRoute(method: "POST", path: "/api/upload/retry") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let jobID = json["jobID"] else {
                return HTTPResponse.error("Missing jobID")
            }
            UploadQueueManager.shared.retry(jobID: jobID)
            return HTTPResponse.ok()
        }

        // Cancel a specific job
        router.addRoute(method: "POST", path: "/api/upload/cancel") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let jobID = json["jobID"] else {
                return HTTPResponse.error("Missing jobID")
            }
            UploadQueueManager.shared.cancel(jobID: jobID)
            return HTTPResponse.ok()
        }

        // Retry all failed jobs
        router.addRoute(method: "POST", path: "/api/upload/retry-failed") { _ in
            UploadQueueManager.shared.retryAllFailed()
            return HTTPResponse.ok()
        }

        // Pause all uploads
        router.addRoute(method: "POST", path: "/api/upload/pause") { _ in
            UploadQueueManager.shared.pauseAll()
            return HTTPResponse.ok()
        }

        // Resume all uploads
        router.addRoute(method: "POST", path: "/api/upload/resume") { _ in
            UploadQueueManager.shared.resumeAll()
            return HTTPResponse.ok()
        }
    }
}
