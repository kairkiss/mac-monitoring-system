import Foundation

struct APITaskHandler {
    static func register(router: WebRouter) {
        // List tasks
        router.addRoute(method: "GET", path: "/api/tasks") { _ in
            let scheduler = AutomationScheduler.shared
            let tasks = scheduler.tasks.map { task in
                [
                    "id": task.id.uuidString,
                    "name": task.name,
                    "type": task.type.rawValue,
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
                "nextFireTime": task.nextFireTime.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "lastFireTime": task.lastFireTime.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "createdAt": ISO8601DateFormatter().string(from: task.createdAt)
            ] as [String: Any])
        }

        // Create task
        router.addRoute(method: "POST", path: "/api/tasks") { request in
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

            let weekdays: Set<Int>
            if let wdArray = json["weekdays"] as? [Int] {
                weekdays = Set(wdArray)
            } else {
                weekdays = [2, 3, 4, 5, 6]
            }

            var task = ScheduledTask(
                name: json["name"] as? String ?? "",
                type: taskType,
                isEnabled: json["isEnabled"] as? Bool ?? true,
                hour: json["hour"] as? Int ?? 8,
                minute: json["minute"] as? Int ?? 0,
                weekdays: weekdays,
                countdownMinutes: json["countdownMinutes"] as? Int ?? 30,
                intervalMinutes: json["intervalMinutes"] as? Int ?? 10,
                durationMinutes: json["durationMinutes"] as? Int ?? 120,
                telegramSend: json["telegramSend"] as? Bool ?? false,
                uploadToCloud: json["uploadToCloud"] as? Bool ?? false,
                uploadProvider: json["uploadProvider"] as? String
            )

            AutomationScheduler.shared.addTask(task)

            return HTTPResponse.json(["id": task.id.uuidString, "ok": true] as [String: Any])
        }

        // Update task
        router.addRoute(method: "PUT", path: "/api/tasks/:id") { request in
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
            if let isEnabled = json["isEnabled"] as? Bool { task.isEnabled = isEnabled }
            if let hour = json["hour"] as? Int { task.hour = hour }
            if let minute = json["minute"] as? Int { task.minute = minute }
            if let wdArray = json["weekdays"] as? [Int] { task.weekdays = Set(wdArray) }
            if let cd = json["countdownMinutes"] as? Int { task.countdownMinutes = cd }
            if let iv = json["intervalMinutes"] as? Int { task.intervalMinutes = iv }
            if let dur = json["durationMinutes"] as? Int { task.durationMinutes = dur }
            if let ts = json["telegramSend"] as? Bool { task.telegramSend = ts }
            if let uc = json["uploadToCloud"] as? Bool { task.uploadToCloud = uc }
            if let up = json["uploadProvider"] as? String { task.uploadProvider = up.isEmpty ? nil : up }

            scheduler.updateTask(task)

            return HTTPResponse.json(["id": task.id.uuidString, "ok": true] as [String: Any])
        }

        // Toggle task
        router.addRoute(method: "POST", path: "/api/tasks/:id/toggle") { request in
            let taskID = router.extractParam("id", from: request, pattern: "/api/tasks/:id/toggle") ?? ""
            let scheduler = AutomationScheduler.shared

            guard let index = scheduler.tasks.firstIndex(where: { $0.id.uuidString == taskID }) else {
                return HTTPResponse.error("Task not found", status: 404)
            }

            scheduler.tasks[index].isEnabled.toggle()
            scheduler.saveAllTasks()
            scheduler.rescheduleAll()

            return HTTPResponse.json(["isEnabled": scheduler.tasks[index].isEnabled])
        }

        // Delete task
        router.addRoute(method: "DELETE", path: "/api/tasks/:id") { request in
            let taskID = router.extractParam("id", from: request, pattern: "/api/tasks/:id") ?? ""
            let scheduler = AutomationScheduler.shared

            guard let index = scheduler.tasks.firstIndex(where: { $0.id.uuidString == taskID }) else {
                return HTTPResponse.error("Task not found", status: 404)
            }

            scheduler.tasks.remove(at: index)
            scheduler.saveAllTasks()
            scheduler.rescheduleAll()

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
