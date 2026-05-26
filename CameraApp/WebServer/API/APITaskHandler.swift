import Foundation

struct APITaskHandler {
    /// Normalize legacy uploadProvider values to match StorageProviderType rawValues
    static func normalizeUploadProvider(_ value: String?) -> String? {
        guard let v = value, !v.isEmpty else { return nil }
        switch v {
        case "google_drive": return "googleDrive"
        case "local": return "localFolder"
        case "mounted": return "mountedFolder"
        default: return v
        }
    }

    static func register(router: WebRouter) {
        // List tasks
        router.addRoute(method: "GET", path: "/api/tasks") { _ in
            let scheduler = AutomationScheduler.shared
            let tasks = scheduler.tasks.map { task in
                [
                    "id": task.id.uuidString,
                    "name": task.name,
                    "type": task.type.rawValue,
                    "actionType": task.actionType.rawValue,
                    "isEnabled": task.isEnabled,
                    "telegramSend": task.telegramSend,
                    "uploadToCloud": task.uploadToCloud,
                    "uploadProvider": task.uploadProvider as Any,
                    "hour": task.hour,
                    "minute": task.minute,
                    "weekdays": Array(task.weekdays),
                    "countdownMinutes": task.countdownMinutes,
                    "intervalMinutes": task.intervalMinutes,
                    "durationMinutes": task.durationMinutes,
                    "intervalRunDurationMinutes": task.intervalRunDurationMinutes,
                    "videoDurationSeconds": task.videoDurationSeconds,
                    "nextFireTime": task.nextFireTime.map { ISO8601DateFormatter().string(from: $0) } as Any,
                    "lastFireTime": task.lastFireTime.map { ISO8601DateFormatter().string(from: $0) } as Any,
                    "createdAt": ISO8601DateFormatter().string(from: task.createdAt)
                ] as [String: Any]
            }
            return HTTPResponse.json(["tasks": tasks])
        }

        // Get task detail
        router.addRoute(method: "GET", path: "/api/tasks/:id") { request in
            let taskID = router.extractParam("id", from: request, pattern: "/api/tasks/:id") ?? ""
            let scheduler = AutomationScheduler.shared

            guard let task = scheduler.tasks.first(where: { $0.id.uuidString == taskID }) else {
                return HTTPResponse.error("Task not found", status: 404)
            }

            return HTTPResponse.json([
                "id": task.id.uuidString,
                "name": task.name,
                "type": task.type.rawValue,
                "actionType": task.actionType.rawValue,
                "isEnabled": task.isEnabled,
                "telegramSend": task.telegramSend,
                "uploadToCloud": task.uploadToCloud,
                "uploadProvider": task.uploadProvider as Any,
                "hour": task.hour,
                "minute": task.minute,
                "weekdays": Array(task.weekdays),
                "countdownMinutes": task.countdownMinutes,
                "intervalMinutes": task.intervalMinutes,
                "durationMinutes": task.durationMinutes,
                "intervalRunDurationMinutes": task.intervalRunDurationMinutes,
                "videoDurationSeconds": task.videoDurationSeconds,
                "nextFireTime": task.nextFireTime.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "lastFireTime": task.lastFireTime.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "createdAt": ISO8601DateFormatter().string(from: task.createdAt)
            ] as [String: Any])
        }

        // Create task
        router.addRoute(method: "POST", path: "/api/tasks", requiredRole: .operatorRole) { request in
            guard let body = request.body else {
                return HTTPResponse.error("Missing body", status: 400)
            }
            guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                return HTTPResponse.error("Invalid JSON", status: 400)
            }

            let taskTypeRaw = json["type"] as? String ?? "daily"
            guard let taskType = TaskType(rawValue: taskTypeRaw) else {
                return HTTPResponse.error("Invalid task type", status: 400)
            }

            let actionTypeRaw = json["actionType"] as? String ?? "photo"
            guard let actionType = TaskActionType(rawValue: actionTypeRaw) else {
                return HTTPResponse.error("Invalid action type", status: 400)
            }

            let weekdays: Set<Int>
            if let wdArray = json["weekdays"] as? [Int] {
                weekdays = Set(wdArray)
            } else {
                weekdays = [2, 3, 4, 5, 6]
            }

            var task = ScheduledTask(
                name: json["name"] as? String ?? "",
                type: taskType,
                actionType: actionType,
                isEnabled: json["isEnabled"] as? Bool ?? true,
                hour: json["hour"] as? Int ?? 8,
                minute: json["minute"] as? Int ?? 0,
                weekdays: weekdays,
                countdownMinutes: json["countdownMinutes"] as? Int ?? 30,
                intervalMinutes: json["intervalMinutes"] as? Int ?? 10,
                durationMinutes: json["durationMinutes"] as? Int ?? 120,
                intervalRunDurationMinutes: json["intervalRunDurationMinutes"] as? Int ?? 0,
                videoDurationSeconds: json["videoDurationSeconds"] as? Int ?? 30,
                telegramSend: json["telegramSend"] as? Bool ?? false,
                uploadToCloud: json["uploadToCloud"] as? Bool ?? false,
                uploadProvider: APITaskHandler.normalizeUploadProvider(json["uploadProvider"] as? String)
            )

            AutomationScheduler.shared.addTask(task)

            AuditLogManager.shared.log(
                method: "POST", path: "/api/tasks", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "create task: \(task.name)"
            )
            return HTTPResponse.json(["id": task.id.uuidString, "ok": true] as [String: Any])
        }

        // Update task
        router.addRoute(method: "PUT", path: "/api/tasks/:id", requiredRole: .operatorRole) { request in
            let taskID = router.extractParam("id", from: request, pattern: "/api/tasks/:id") ?? ""
            let scheduler = AutomationScheduler.shared

            guard let index = scheduler.tasks.firstIndex(where: { $0.id.uuidString == taskID }) else {
                return HTTPResponse.error("Task not found", status: 404)
            }

            guard let body = request.body else {
                return HTTPResponse.error("Missing body", status: 400)
            }
            guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                return HTTPResponse.error("Invalid JSON", status: 400)
            }

            var task = scheduler.tasks[index]

            if let name = json["name"] as? String { task.name = name }
            if let typeRaw = json["type"] as? String, let type = TaskType(rawValue: typeRaw) { task.type = type }
            if let actionRaw = json["actionType"] as? String, let action = TaskActionType(rawValue: actionRaw) { task.actionType = action }
            if let isEnabled = json["isEnabled"] as? Bool { task.isEnabled = isEnabled }
            if let hour = json["hour"] as? Int { task.hour = hour }
            if let minute = json["minute"] as? Int { task.minute = minute }
            if let wdArray = json["weekdays"] as? [Int] { task.weekdays = Set(wdArray) }
            if let cd = json["countdownMinutes"] as? Int { task.countdownMinutes = cd }
            if let iv = json["intervalMinutes"] as? Int { task.intervalMinutes = iv }
            if let dur = json["durationMinutes"] as? Int { task.durationMinutes = dur }
            if let ird = json["intervalRunDurationMinutes"] as? Int { task.intervalRunDurationMinutes = ird }
            if let vds = json["videoDurationSeconds"] as? Int { task.videoDurationSeconds = vds }
            if let ts = json["telegramSend"] as? Bool { task.telegramSend = ts }
            if let uc = json["uploadToCloud"] as? Bool { task.uploadToCloud = uc }
            if let up = json["uploadProvider"] as? String { task.uploadProvider = up.isEmpty ? nil : APITaskHandler.normalizeUploadProvider(up) }

            scheduler.updateTask(task)

            AuditLogManager.shared.log(
                method: "PUT", path: "/api/tasks/:id", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "update task: \(taskID)"
            )
            return HTTPResponse.json(["id": task.id.uuidString, "ok": true] as [String: Any])
        }

        // Toggle task
        router.addRoute(method: "POST", path: "/api/tasks/:id/toggle", requiredRole: .operatorRole) { request in
            let taskID = router.extractParam("id", from: request, pattern: "/api/tasks/:id/toggle") ?? ""
            let scheduler = AutomationScheduler.shared

            guard let index = scheduler.tasks.firstIndex(where: { $0.id.uuidString == taskID }) else {
                return HTTPResponse.error("Task not found", status: 404)
            }

            scheduler.tasks[index].isEnabled.toggle()
            scheduler.saveAllTasks()
            scheduler.rescheduleAll()

            AuditLogManager.shared.log(
                method: "POST", path: "/api/tasks/:id/toggle", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "toggle task: \(taskID)"
            )
            return HTTPResponse.json(["isEnabled": scheduler.tasks[index].isEnabled])
        }

        // Delete task
        router.addRoute(method: "DELETE", path: "/api/tasks/:id", requiredRole: .operatorRole) { request in
            let taskID = router.extractParam("id", from: request, pattern: "/api/tasks/:id") ?? ""
            let scheduler = AutomationScheduler.shared

            guard let index = scheduler.tasks.firstIndex(where: { $0.id.uuidString == taskID }) else {
                return HTTPResponse.error("Task not found", status: 404)
            }

            scheduler.tasks.remove(at: index)
            scheduler.saveAllTasks()
            scheduler.rescheduleAll()

            AuditLogManager.shared.log(
                method: "DELETE", path: "/api/tasks/:id", status: 200,
                remoteAddress: request.remoteAddress ?? "unknown",
                user: request.sessionUsername,
                detail: "delete task: \(taskID)"
            )
            return HTTPResponse.ok()
        }

        // Task history
        router.addRoute(method: "GET", path: "/api/tasks/history") { _ in
            let history = AutomationScheduler.shared.executionHistory.prefix(50).map { record in
                [
                    "taskName": record.taskName,
                    "executedAt": ISO8601DateFormatter().string(from: record.timestamp),
                    "success": record.succeeded,
                    "detail": record.detail ?? ""
                ] as [String: Any]
            }
            return HTTPResponse.json(["history": Array(history)])
        }
    }
}
