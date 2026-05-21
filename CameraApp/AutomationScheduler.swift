import Foundation
import AppKit

enum TaskType: String, Codable, CaseIterable {
    case daily
    case weekly
    case countdown
    case interval

    var displayName: String {
        switch self {
        case .daily: return Strings.dailyAt
        case .weekly: return Strings.weeklyOn
        case .countdown: return Strings.countdown
        case .interval: return Strings.interval
        }
    }
}

struct ScheduledTask: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: TaskType
    var isEnabled: Bool
    var hour: Int
    var minute: Int
    var weekdays: Set<Int>  // 1=Sunday ... 7=Saturday
    var countdownMinutes: Int
    var intervalMinutes: Int
    var durationMinutes: Int
    var telegramSend: Bool
    let createdAt: Date
    var nextFireTime: Date?
    var lastRunAt: Date?
    var lastFireTime: Date? { lastRunAt }
    var lastAttemptAt: Date?

    init(
        id: UUID = UUID(),
        name: String = "",
        type: TaskType = .daily,
        isEnabled: Bool = true,
        hour: Int = 8,
        minute: Int = 0,
        weekdays: Set<Int> = [2, 3, 4, 5, 6],
        countdownMinutes: Int = 30,
        intervalMinutes: Int = 10,
        durationMinutes: Int = 120,
        telegramSend: Bool = false,
        createdAt: Date = Date(),
        nextFireTime: Date? = nil,
        lastRunAt: Date? = nil,
        lastAttemptAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.countdownMinutes = countdownMinutes
        self.intervalMinutes = intervalMinutes
        self.durationMinutes = durationMinutes
        self.telegramSend = telegramSend
        self.createdAt = createdAt
        self.nextFireTime = nextFireTime
        self.lastRunAt = lastRunAt
        self.lastAttemptAt = lastAttemptAt
    }
}

struct ExecutionRecord: Identifiable, Codable {
    let id: UUID
    let taskID: UUID
    let taskName: String
    let timestamp: Date
    let succeeded: Bool
    let detail: String?
}

final class AutomationScheduler: ObservableObject {
    static let shared = AutomationScheduler()

    @Published var tasks: [ScheduledTask] = []
    @Published var executionHistory: [ExecutionRecord] = []
    @Published var isAutomationEnabled: Bool {
        didSet { UserDefaults.standard.set(isAutomationEnabled, forKey: "automationEnabled") }
    }

    var onCapture: ((Bool) -> Void)?  // takes telegramSend flag

    private var activeTimers: [UUID: Timer] = [:]
    private var intervalStopTimers: [UUID: Timer] = [:]
    private var retryTimers: [UUID: Timer] = [:]

    private init() {
        isAutomationEnabled = UserDefaults.standard.bool(forKey: "automationEnabled")
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    @objc private func systemDidWake() {
        guard isAutomationEnabled else { return }
        recoverMissedTasks()
    }

    // MARK: - CRUD

    func addTask(_ task: ScheduledTask) {
        var task = task
        task.nextFireTime = calculateNextFireTime(for: task)
        tasks.append(task)
        if task.isEnabled && isAutomationEnabled {
            scheduleTimer(for: task)
        }
        persistTasks()
    }

    func updateTask(_ task: ScheduledTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.nextFireTime = calculateNextFireTime(for: updated)
        tasks[index] = updated
        cancelTimer(for: task.id)
        if updated.isEnabled && isAutomationEnabled {
            scheduleTimer(for: updated)
        }
        persistTasks()
    }

    func deleteTask(_ task: ScheduledTask) {
        cancelTimer(for: task.id)
        tasks.removeAll { $0.id == task.id }
        persistTasks()
    }

    func toggleTask(_ task: ScheduledTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isEnabled.toggle()
        if tasks[index].isEnabled && isAutomationEnabled {
            scheduleTimer(for: tasks[index])
        } else {
            cancelTimer(for: task.id)
        }
        persistTasks()
    }

    // MARK: - Global Control

    func setAutomationEnabled(_ enabled: Bool) {
        isAutomationEnabled = enabled
        if enabled {
            restoreAllTasks()
        } else {
            cancelAllTimers()
        }
    }

    func captureNow() {
        onCapture?(false)
    }

    // MARK: - Restore

    // MARK: - Execution History

    func logExecution(taskID: UUID, taskName: String, succeeded: Bool, detail: String? = nil) {
        let record = ExecutionRecord(
            id: UUID(),
            taskID: taskID,
            taskName: taskName,
            timestamp: Date(),
            succeeded: succeeded,
            detail: detail
        )
        executionHistory.insert(record, at: 0)
        if executionHistory.count > 1000 {
            executionHistory = Array(executionHistory.prefix(1000))
        }
        persistHistory()
    }

    func executions(for taskID: UUID) -> [ExecutionRecord] {
        executionHistory.filter { $0.taskID == taskID }
    }

    var todayCaptureCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return executionHistory.filter { $0.timestamp >= startOfDay }.count
    }

    var todayTelegramCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return executionHistory.filter { $0.timestamp >= startOfDay && $0.succeeded }.count
    }

    private var historyFileURL: URL {
        MediaLibraryManager.shared.baseDirectory.appendingPathComponent("execution_history.json")
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(executionHistory) else { return }
        _ = MediaLibraryManager.shared.writeAtomically(data, to: historyFileURL)
    }

    private func loadHistory() -> [ExecutionRecord] {
        guard let data = try? Data(contentsOf: historyFileURL) else { return [] }
        return (try? JSONDecoder().decode([ExecutionRecord].self, from: data)) ?? []
    }

    // MARK: - Restore

    func restoreAllTasks() {
        let loaded = loadTasks()
        tasks = loaded
        executionHistory = loadHistory()
        cancelAllTimers()
        guard isAutomationEnabled else { return }
        recoverMissedTasks()
        for i in tasks.indices {
            tasks[i].nextFireTime = calculateNextFireTime(for: tasks[i])
            if tasks[i].isEnabled {
                scheduleTimer(for: tasks[i])
            }
        }
        persistTasks()
    }

    func recoverMissedTasks() {
        let windowMinutes = SettingsStore.shared.recoveryWindowMinutes
        guard windowMinutes > 0 else { return }
        let now = Date()
        let cutoff = now.addingTimeInterval(-TimeInterval(windowMinutes * 60))

        for i in tasks.indices {
            guard tasks[i].isEnabled else { continue }
            guard isAutomationEnabled else { continue }

            guard let expected = expectedLastFireTime(for: tasks[i]) else { continue }
            guard expected >= cutoff && expected <= now else { continue }

            let lastRun = tasks[i].lastRunAt
            guard lastRun == nil || lastRun! < expected else { continue }

            let taskName = tasks[i].name.isEmpty ? tasks[i].type.displayName : tasks[i].name
            let telegramSend = tasks[i].telegramSend
            ActivityLogManager.shared.log(
                level: .info,
                category: .automation,
                message: "Recovering missed task: \(taskName)",
                detail: "Expected at: \(expected), last run: \(lastRun?.description ?? "never")"
            )
            onCapture?(telegramSend)
            tasks[i].lastRunAt = now
            tasks[i].lastAttemptAt = now
            tasks[i].nextFireTime = calculateNextFireTime(for: tasks[i])
        }
        persistTasks()
    }

    /// Calculate the most recent time this task should have fired, based on its rules.
    func expectedLastFireTime(for task: ScheduledTask) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        switch task.type {
        case .daily:
            // Today at the configured time
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = task.hour
            components.minute = task.minute
            components.second = 0
            guard let todayTarget = calendar.date(from: components) else { return nil }
            if todayTarget <= now {
                return todayTarget
            } else {
                // Today's time hasn't passed yet, use yesterday
                return calendar.date(byAdding: .day, value: -1, to: todayTarget)
            }

        case .weekly:
            // Go backwards up to 7 days to find the most recent matching weekday
            for offset in 0...7 {
                guard let candidateDate = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
                let weekday = calendar.component(.weekday, from: candidateDate)
                guard task.weekdays.contains(weekday) else { continue }
                var components = calendar.dateComponents([.year, .month, .day], from: candidateDate)
                components.hour = task.hour
                components.minute = task.minute
                components.second = 0
                guard let targetTime = calendar.date(from: components) else { continue }
                if targetTime <= now {
                    return targetTime
                }
            }
            return nil

        case .countdown, .interval:
            return nil
        }
    }

    // MARK: - Timer Scheduling

    private func scheduleTimer(for task: ScheduledTask) {
        cancelTimer(for: task.id)

        guard let fireDate = task.nextFireTime, fireDate > Date() else {
            if let newFireDate = calculateNextFireTime(for: task) {
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[index].nextFireTime = newFireDate
                }
                let timer = Timer(fire: newFireDate, interval: 0, repeats: false) { [weak self] _ in
                    self?.handleTimerFired(taskID: task.id)
                }
                RunLoop.main.add(timer, forMode: .common)
                activeTimers[task.id] = timer
            }
            return
        }

        switch task.type {
        case .daily, .weekly, .countdown:
            let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
                self?.handleTimerFired(taskID: task.id)
            }
            RunLoop.main.add(timer, forMode: .common)
            activeTimers[task.id] = timer

        case .interval:
            let intervalSeconds = TimeInterval(task.intervalMinutes * 60)
            let timer = Timer(timeInterval: intervalSeconds, repeats: true) { [weak self] _ in
                self?.handleTimerFired(taskID: task.id)
            }
            timer.fireDate = fireDate
            RunLoop.main.add(timer, forMode: .common)
            activeTimers[task.id] = timer

            if task.durationMinutes > 0 {
                let stopDate = fireDate.addingTimeInterval(TimeInterval(task.durationMinutes * 60))
                let stopTimer = Timer(fire: stopDate, interval: 0, repeats: false) { [weak self] _ in
                    self?.cancelTimer(for: task.id)
                    if let index = self?.tasks.firstIndex(where: { $0.id == task.id }) {
                        self?.tasks[index].isEnabled = false
                        self?.persistTasks()
                    }
                }
                RunLoop.main.add(stopTimer, forMode: .common)
                intervalStopTimers[task.id] = stopTimer
            }
        }
    }

    private func cancelTimer(for taskID: UUID) {
        activeTimers[taskID]?.invalidate()
        activeTimers.removeValue(forKey: taskID)
        intervalStopTimers[taskID]?.invalidate()
        intervalStopTimers.removeValue(forKey: taskID)
        retryTimers[taskID]?.invalidate()
        retryTimers.removeValue(forKey: taskID)
    }

    private func cancelAllTimers() {
        for (_, timer) in activeTimers { timer.invalidate() }
        activeTimers.removeAll()
        for (_, timer) in intervalStopTimers { timer.invalidate() }
        intervalStopTimers.removeAll()
        for (_, timer) in retryTimers { timer.invalidate() }
        retryTimers.removeAll()
    }

    private func handleTimerFired(taskID: UUID) {
        guard isAutomationEnabled else { return }
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard tasks[index].isEnabled else { return }

        let now = Date()
        tasks[index].lastRunAt = now
        tasks[index].lastAttemptAt = now
        let telegramSend = tasks[index].telegramSend

        // Check camera availability before capturing
        let camera = CameraManager.shared
        if camera.isCameraBusyByOtherApp {
            // Camera is occupied, retry in 5 minutes
            tasks[index].lastAttemptAt = Date()
            scheduleRetry(for: taskID, after: 300)
            return
        }

        onCapture?(telegramSend)

        let taskName = tasks[index].name.isEmpty ? tasks[index].type.displayName : tasks[index].name
        logExecution(taskID: taskID, taskName: taskName, succeeded: true)
        ActivityLogManager.shared.log(level: .success, category: .automation, message: "Task fired: \(taskName)", taskID: taskID.uuidString, taskName: taskName)

        // Reschedule
        switch tasks[index].type {
        case .daily, .weekly:
            tasks[index].nextFireTime = calculateNextFireTime(for: tasks[index])
            if let next = tasks[index].nextFireTime {
                let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
                    self?.handleTimerFired(taskID: taskID)
                }
                RunLoop.main.add(timer, forMode: .common)
                activeTimers[taskID] = timer
            }
        case .countdown:
            tasks[index].isEnabled = false
            tasks[index].nextFireTime = nil
        case .interval:
            let intervalSeconds = TimeInterval(tasks[index].intervalMinutes * 60)
            tasks[index].nextFireTime = Date().addingTimeInterval(intervalSeconds)
        }

        persistTasks()
    }

    private func scheduleRetry(for taskID: UUID, after seconds: TimeInterval) {
        retryTimers[taskID]?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.handleTimerFired(taskID: taskID)
        }
        retryTimers[taskID] = timer
    }

    // MARK: - Next Fire Time Calculation

    private func calculateNextFireTime(for task: ScheduledTask) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        switch task.type {
        case .daily:
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = task.hour
            components.minute = task.minute
            components.second = 0
            guard let targetTime = calendar.date(from: components) else { return nil }
            if targetTime > now {
                return targetTime
            } else {
                return calendar.date(byAdding: .day, value: 1, to: targetTime)
            }

        case .weekly:
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = task.hour
            components.minute = task.minute
            components.second = 0
            guard let todayTarget = calendar.date(from: components) else { return nil }

            for offset in 0...7 {
                let candidateDate = calendar.date(byAdding: .day, value: offset, to: todayTarget)!
                let candidateWeekday = calendar.component(.weekday, from: candidateDate)
                if task.weekdays.contains(candidateWeekday) {
                    if offset == 0 && candidateDate <= now { continue }
                    return candidateDate
                }
            }
            return nil

        case .countdown:
            return now.addingTimeInterval(TimeInterval(task.countdownMinutes * 60))

        case .interval:
            return now
        }
    }

    // MARK: - Persistence

    private var tasksFileURL: URL {
        MediaLibraryManager.shared.baseDirectory.appendingPathComponent("tasks.json")
    }

    private func persistTasks() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: tasksFileURL)
    }

    func saveAllTasks() {
        persistTasks()
    }

    func rescheduleAll() {
        for task in tasks {
            cancelTimer(for: task.id)
            if task.isEnabled && isAutomationEnabled {
                scheduleTimer(for: task)
            }
        }
    }

    private func loadTasks() -> [ScheduledTask] {
        guard let data = try? Data(contentsOf: tasksFileURL) else { return [] }
        return (try? JSONDecoder().decode([ScheduledTask].self, from: data)) ?? []
    }
}
