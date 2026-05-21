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

    func generateNow() {
        generateReport()
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let today = formatter.string(from: Date())
        let index = MediaIndexStore.shared
        let health = HealthMonitor.shared

        // Photo filenames: Photo_yyyyMMdd_HHmmss.jpg — match yyyyMMdd portion
        let todayPhotos = index.entries.filter { key, value in
            value.source != .event && key.contains(today)
        }.count
        let todayVideos = index.entries.filter { key, value in
            value.source == .event && key.contains(today)
        }.count
        let uploads = index.entries.filter { $0.value.uploadDate != nil }.count
        let failures = index.entries.filter { $0.value.uploadStatus == .failed }.count
        let motionEvents = index.items(withSource: .motion).count

        // Use display date with hyphens for the report
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd"
        let displayDate = displayFormatter.string(from: Date())

        let report = DailyReport(
            date: displayDate,
            photoCount: todayPhotos,
            videoCount: todayVideos,
            uploadCount: uploads,
            uploadFailures: failures,
            motionEvents: motionEvents,
            alerts: health.alerts.count,
            diskFreeMB: health.diskFreeMB
        )

        saveReport(report)
        ActivityLogManager.shared.info(.report, "Daily report generated for \(displayDate)")
        scheduleNext()
    }

    private func saveReport(_ report: DailyReport) {
        let url = MediaLibraryManager.shared.reportsDirectory.appendingPathComponent("\(report.date).json")
        guard let data = try? JSONEncoder().encode(report) else { return }
        try? data.write(to: url)
    }
}
