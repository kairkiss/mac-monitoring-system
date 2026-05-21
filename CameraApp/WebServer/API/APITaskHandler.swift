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
                    "nextFireTime": task.nextFireTime.map { ISO8601DateFormatter().string(from: $0) } as Any
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
                "nextFireTime": task.nextFireTime.map { ISO8601DateFormatter().string(from: $0) } as Any,
                "lastFireTime": task.lastFireTime.map { ISO8601DateFormatter().string(from: $0) } as Any
            ] as [String: Any])
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
