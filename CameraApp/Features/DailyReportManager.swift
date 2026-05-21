import Foundation

struct DailyReport: Codable {
    let date: String
    let photoCount: Int
    let videoCount: Int
    let uploadCount: Int
    let uploadFailures: Int
    let motionEvents: Int
    let alerts: Int
    let diskFreeMB: Int64
}

final class DailyReportManager {
    static let shared = DailyReportManager()

    private var timer: Timer?

    private init() {}

    func start() {
        guard SettingsStore.shared.dailyReportEnabled else { return }
        scheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNext() {
        let settings = SettingsStore.shared
        let now = Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = settings.dailyReportHour
        components.minute = settings.dailyReportMinute
        var fireDate = Calendar.current.date(from: components) ?? now
        if fireDate <= now {
            fireDate = Calendar.current.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }
        timer = Timer(fireAt: fireDate, interval: 0, target: self, selector: #selector(generateReport), userInfo: nil, repeats: false)
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc private func generateReport() {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let index = MediaIndexStore.shared
        let health = HealthMonitor.shared

        let todayPhotos = index.entries.filter { $0.value.source != .event && $0.key.contains(String(today)) }.count
        let todayVideos = index.entries.filter { $0.value.source == .event && $0.key.contains(String(today)) }.count
        let uploads = index.entries.filter { $0.value.uploadDate != nil }.count
        let failures = index.entries.filter { $0.value.uploadStatus == .failed }.count
        let motionEvents = index.items(withSource: .motion).count

        let report = DailyReport(
            date: String(today),
            photoCount: todayPhotos,
            videoCount: todayVideos,
            uploadCount: uploads,
            uploadFailures: failures,
            motionEvents: motionEvents,
            alerts: health.alerts.count,
            diskFreeMB: health.diskFreeMB
        )

        saveReport(report)
        ActivityLogManager.shared.info(.report, "Daily report generated for \(today)")
        scheduleNext()
    }

    private func saveReport(_ report: DailyReport) {
        let url = MediaLibraryManager.shared.baseDirectory.appendingPathComponent("reports/\(report.date).json")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(report) else { return }
        try? data.write(to: url)
    }
}
