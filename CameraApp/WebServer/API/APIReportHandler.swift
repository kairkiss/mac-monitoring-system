import Foundation

struct APIReportHandler {
    static func register(router: WebRouter) {
        // Get latest daily report
        router.addRoute(method: "GET", path: "/api/reports/latest") { _ in
            let reportsDir = MediaLibraryManager.shared.reportsDirectory
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: reportsDir, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]
            ) else {
                return HTTPResponse.json(["report": NSNull()])
            }
            let sorted = files.sorted { $0.lastPathComponent > $1.lastPathComponent }
            guard let latest = sorted.first,
                  let data = try? Data(contentsOf: latest),
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                return HTTPResponse.json(["report": NSNull()])
            }
            return HTTPResponse.json(["report": json])
        }

        // List all reports
        router.addRoute(method: "GET", path: "/api/reports") { _ in
            let reportsDir = MediaLibraryManager.shared.reportsDirectory
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: reportsDir, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]
            ) else {
                return HTTPResponse.json(["reports": []])
            }
            let sorted = files.sorted { $0.lastPathComponent > $1.lastPathComponent }
            let reports = sorted.prefix(30).compactMap { url -> [String: Any]? in
                guard let data = try? Data(contentsOf: url),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
                return json
            }
            return HTTPResponse.json(["reports": reports])
        }

        // Trigger manual report generation
        router.addRoute(method: "POST", path: "/api/reports/generate") { _ in
            DailyReportManager.shared.generateNow()
            return HTTPResponse.ok()
        }

        // Timelapse status
        router.addRoute(method: "GET", path: "/api/timelapse/status") { _ in
            let tl = TimelapseManager.shared
            return HTTPResponse.json([
                "isCapturing": tl.isCapturing,
                "frameCount": tl.frameCount,
                "enabled": SettingsStore.shared.timelapseEnabled
            ] as [String: Any])
        }

        // Start timelapse
        router.addRoute(method: "POST", path: "/api/timelapse/start") { _ in
            TimelapseManager.shared.start()
            return HTTPResponse.ok()
        }

        // Stop timelapse
        router.addRoute(method: "POST", path: "/api/timelapse/stop") { _ in
            TimelapseManager.shared.stop()
            return HTTPResponse.ok()
        }
    }
}
