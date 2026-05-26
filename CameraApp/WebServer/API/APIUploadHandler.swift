import Foundation

struct APIUploadHandler {
    static func register(router: WebRouter) {
        // Get upload queue
        router.addRoute(method: "GET", path: "/api/upload/queue") { _ in
            let queue = UploadQueueManager.shared
            let fmt = ISO8601DateFormatter()
            let jobs = queue.jobs.map { job -> [String: Any] in
                [
                    "id": job.id,
                    "fileName": job.fileName,
                    "status": job.status.rawValue,
                    "provider": job.providerType,
                    "attempts": job.attempts,
                    "maxRetries": job.maxRetries,
                    "progress": job.progress,
                    "lastError": job.lastError ?? "",
                    "errorClass": job.errorClass ?? "",
                    "createdAt": fmt.string(from: job.createdAt),
                    "startedAt": job.startedAt.map { fmt.string(from: $0) } ?? "",
                    "completedAt": job.completedAt.map { fmt.string(from: $0) } ?? "",
                    "nextRetryAt": job.nextRetryAt.map { fmt.string(from: $0) } ?? "",
                    "lastAttemptAt": job.lastAttemptAt.map { fmt.string(from: $0) } ?? "",
                    "retryDelaySeconds": job.retryDelaySeconds ?? 0,
                    "fileSize": job.fileSize ?? 0
                ] as [String: Any]
            }
            return HTTPResponse.json([
                "jobs": jobs,
                "isPaused": queue.isPaused,
                "totalJobs": queue.jobs.count,
                "pendingCount": queue.jobs.filter { $0.status == .pending }.count,
                "retryingCount": queue.jobs.filter { $0.status == .retrying }.count,
                "uploadingCount": queue.jobs.filter { $0.status == .uploading }.count,
                "completedCount": queue.jobs.filter { $0.status == .completed }.count,
                "failedCount": queue.jobs.filter { $0.status == .failed }.count,
                "waitingCount": queue.jobs.filter { $0.status == .waitingForProvider }.count
            ] as [String: Any])
        }

        // Retry a specific job
        router.addRoute(method: "POST", path: "/api/upload/retry", requiredRole: .operatorRole) { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let jobID = json["jobID"] else {
                return HTTPResponse.error("Missing jobID")
            }
            UploadQueueManager.shared.retry(jobID: jobID)
            return HTTPResponse.ok()
        }

        // Cancel a specific job
        router.addRoute(method: "POST", path: "/api/upload/cancel", requiredRole: .operatorRole) { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let jobID = json["jobID"] else {
                return HTTPResponse.error("Missing jobID")
            }
            UploadQueueManager.shared.cancel(jobID: jobID)
            return HTTPResponse.ok()
        }

        // Retry all failed jobs
        router.addRoute(method: "POST", path: "/api/upload/retry-failed", requiredRole: .operatorRole) { request in
            UploadQueueManager.shared.retryAllFailed()
            AuditLogManager.shared.log(
                method: "POST", path: "/api/upload/retry-failed", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "retry all failed"
            )
            return HTTPResponse.ok()
        }

        // Pause all uploads
        router.addRoute(method: "POST", path: "/api/upload/pause", requiredRole: .operatorRole) { request in
            UploadQueueManager.shared.pauseAll()
            AuditLogManager.shared.log(
                method: "POST", path: "/api/upload/pause", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "pause queue"
            )
            return HTTPResponse.ok()
        }

        // Resume all uploads
        router.addRoute(method: "POST", path: "/api/upload/resume", requiredRole: .operatorRole) { request in
            UploadQueueManager.shared.resumeAll()
            AuditLogManager.shared.log(
                method: "POST", path: "/api/upload/resume", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "resume queue"
            )
            return HTTPResponse.ok()
        }
    }
}
