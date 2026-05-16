import SwiftUI

struct AutomationView: View {
    @EnvironmentObject var automation: AutomationScheduler
    @EnvironmentObject var lang: LanguageManager
    @State private var showingNewTask = false
    @State private var editingTask: ScheduledTask?
    @State private var showToast = false
    @State private var toastText = ""
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle(Strings.automationEnabled, isOn: Binding(
                    get: { automation.isAutomationEnabled },
                    set: { automation.setAutomationEnabled($0) }
                ))
                .toggleStyle(.switch)

                Spacer()

                Button {
                    automation.captureNow()
                } label: {
                    Label(Strings.captureNow, systemImage: "camera.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showingNewTask = true
                } label: {
                    Label(Strings.newTask, systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)

            Divider()

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text(Strings.scheduledTasks).tag(0)
                Text(Strings.timeline).tag(1)
                Text(Strings.history).tag(2)
                Text(Strings.statistics).tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            switch selectedTab {
            case 0:
                if automation.tasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            case 1:
                timelineView
            case 2:
                historyView
            case 3:
                statisticsView
            default:
                EmptyView()
            }
        }
        .navigationTitle(Strings.automationTitle)
        .sheet(isPresented: $showingNewTask) {
            TaskEditSheet(task: nil) { newTask in
                automation.addTask(newTask)
                toastText = Strings.taskCreated
                withAnimation { showToast = true }
            }
        }
        .sheet(item: $editingTask) { task in
            TaskEditSheet(task: task) { updated in
                automation.updateTask(updated)
            }
        }
        .overlay(alignment: .top) {
            if showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(toastText)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showToast = false }
                    }
                }
            }
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(automation.tasks) { task in
                    taskCard(task)
                }
            }
            .padding(20)
        }
    }

    private func taskCard(_ task: ScheduledTask) -> some View {
        HStack(spacing: 14) {
            Toggle("", isOn: Binding(
                get: { task.isEnabled },
                set: { _ in automation.toggleTask(task) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(task.name.isEmpty ? task.type.displayName : task.name)
                        .font(.headline)

                    if task.telegramSend {
                        Image(systemName: "paperplane.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Text(taskDescription(task))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let next = task.nextFireTime, task.isEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(Strings.nextExecution): \(next, style: .relative)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                editingTask = task
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .opacity(task.isEnabled ? 1.0 : 0.5)
    }

    private func taskDescription(_ task: ScheduledTask) -> String {
        switch task.type {
        case .daily:
            return "\(Strings.dailyAt) \(String(format: "%02d:%02d", task.hour, task.minute))"
        case .weekly:
            let days = task.weekdays.sorted().map { Strings.weekdays[$0 - 1] }.joined(separator: ", ")
            return "\(Strings.weeklyOn) \(days) \(String(format: "%02d:%02d", task.hour, task.minute))"
        case .countdown:
            return "\(Strings.countdown) \(task.countdownMinutes) \(Strings.minutes)"
        case .interval:
            return "\(Strings.every) \(task.intervalMinutes) \(Strings.minutes), \(Strings.for_) \(task.durationMinutes) \(Strings.minutes)"
        }
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(Strings.todayCaptures)
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // 24-hour timeline
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        timelineRow(hour: hour)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func timelineRow(hour: Int) -> some View {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let hourStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
        let hourEnd = calendar.date(byAdding: .hour, value: hour + 1, to: startOfDay)!
        let events = automation.executionHistory.filter { $0.timestamp >= hourStart && $0.timestamp < hourEnd }

        return HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d:00", hour))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)

            Rectangle()
                .fill(events.isEmpty ? Color.clear : Color.accentColor)
                .frame(width: 3)
                .frame(minHeight: 24)

            if events.isEmpty {
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(events) { event in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(event.succeeded ? .green : .red)
                                .frame(width: 6, height: 6)
                            Text(event.taskName)
                                .font(.caption)
                                .lineLimit(1)
                            Text(event.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - History View

    private var historyView: some View {
        Group {
            if automation.executionHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text(Strings.noHistoryYet)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(automation.executionHistory) { record in
                            historyRow(record)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private func historyRow(_ record: ExecutionRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(record.succeeded ? .green : .red)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.taskName)
                    .font(.subheadline.weight(.medium))
                Text(record.timestamp, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(record.timestamp, style: .time)
                    .font(.caption.monospaced())
                if let detail = record.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Statistics View

    private var statisticsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Stat cards
                HStack(spacing: 12) {
                    statCard(
                        icon: "camera.fill",
                        color: .blue,
                        title: Strings.todayCaptures,
                        value: "\(automation.todayCaptureCount)"
                    )
                    statCard(
                        icon: "paperplane.fill",
                        color: .green,
                        title: Strings.todayTelegramSends,
                        value: "\(automation.todayTelegramCount)"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                HStack(spacing: 12) {
                    statCard(
                        icon: "number",
                        color: .purple,
                        title: Strings.totalExecutions,
                        value: "\(automation.executionHistory.count)"
                    )
                    statCard(
                        icon: "percent",
                        color: .orange,
                        title: Strings.successRate,
                        value: successRateString
                    )
                }
                .padding(.horizontal, 20)

                // Per-task stats
                if !automation.tasks.isEmpty {
                    Text(Strings.taskStatistics)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    ForEach(automation.tasks) { task in
                        perTaskRow(task)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func statCard(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title.bold().monospaced())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    private func perTaskRow(_ task: ScheduledTask) -> some View {
        let taskExecutions = automation.executions(for: task.id)
        let successCount = taskExecutions.filter { $0.succeeded }.count
        let totalCount = taskExecutions.count

        return HStack(spacing: 12) {
            Image(systemName: task.isEnabled ? "clock.fill" : "clock")
                .foregroundStyle(task.isEnabled ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name.isEmpty ? task.type.displayName : task.name)
                    .font(.subheadline.weight(.medium))
                Text("\(totalCount) \(Strings.executionHistory)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if totalCount > 0 {
                Text("\(successCount)/\(totalCount)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    private var successRateString: String {
        let total = automation.executionHistory.count
        guard total > 0 else { return "--" }
        let success = automation.executionHistory.filter { $0.succeeded }.count
        return String(format: "%.0f%%", Double(success) / Double(total) * 100)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 80, height: 80)
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
            }
            Text(Strings.noTasksYet)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(Strings.noTasksDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Task Edit Sheet

struct TaskEditSheet: View {
    let task: ScheduledTask?
    let onSave: (ScheduledTask) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var lang: LanguageManager

    @State private var name: String = ""
    @State private var type: TaskType = .daily
    @State private var hour: Int = 8
    @State private var minute: Int = 0
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var countdownMinutes: Int = 30
    @State private var intervalMinutes: Int = 10
    @State private var durationMinutes: Int = 120
    @State private var telegramSend: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(Strings.cancel) { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Text(task == nil ? Strings.newTask : Strings.editTask)
                    .font(.headline)
                Spacer()
                Button(Strings.save) { save() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField(Strings.taskName, text: $name)
                } header: {
                    Label(Strings.taskName, systemImage: "text.cursor")
                }

                Section {
                    Picker(Strings.taskType, selection: $type) {
                        ForEach(TaskType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Label(Strings.taskType, systemImage: "list.bullet")
                }

                // Time picker - numeric style for all types that need time
                if type == .daily || type == .weekly {
                    Section {
                        HStack(spacing: 20) {
                            // Hour
                            HStack(spacing: 4) {
                                Text("时")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                Picker("", selection: $hour) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(String(format: "%02d", h)).tag(h)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 80)
                            }

                            Text(":")
                                .font(.title2.bold())
                                .foregroundStyle(.secondary)

                            // Minute
                            HStack(spacing: 4) {
                                Text("分")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                Picker("", selection: $minute) {
                                    ForEach(0..<60, id: \.self) { m in
                                        Text(String(format: "%02d", m)).tag(m)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 80)
                            }

                            Divider()

                            // Quick presets
                            VStack(spacing: 4) {
                                ForEach([(8, 0, "早8:00"), (12, 0, "午12:00"), (18, 0, "晚6:00"), (22, 0, "晚10:00")], id: \.0) { h, m, label in
                                    Button(label) {
                                        hour = h
                                        minute = m
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }
                        }
                    } header: {
                        Label(type == .daily ? Strings.dailyAt : Strings.weeklyOn, systemImage: "clock")
                    }
                }

                if type == .weekly {
                    Section {
                        weekdayToggles
                    } header: {
                        Label("选择星期", systemImage: "calendar")
                    }
                }

                switch type {
                case .daily, .weekly:
                    EmptyView()

                case .countdown:
                    Section {
                        Stepper("\(countdownMinutes) \(Strings.minutes)", value: $countdownMinutes, in: 1...1440)

                        // Quick presets
                        HStack(spacing: 8) {
                            ForEach([1, 5, 10, 30, 60], id: \.self) { m in
                                Button("\(m)分") {
                                    countdownMinutes = m
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    } header: {
                        Label(Strings.countdown, systemImage: "timer")
                    } footer: {
                        Text("从现在开始倒计时，\(countdownMinutes) 分钟后自动拍照")
                            .font(.caption)
                    }

                case .interval:
                    Section {
                        Stepper("\(Strings.every) \(intervalMinutes) \(Strings.minutes)", value: $intervalMinutes, in: 1...1440)
                        Stepper("\(Strings.for_) \(durationMinutes) \(Strings.minutes)", value: $durationMinutes, in: 1...10080)
                    } header: {
                        Label(Strings.interval, systemImage: "repeat")
                    } footer: {
                        let count = durationMinutes / intervalMinutes
                        Text("将执行约 \(count) 次拍照")
                            .font(.caption)
                    }
                }

                Section {
                    Toggle(isOn: $telegramSend) {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(.blue)
                            Text(Strings.sendToTelegram)
                        }
                    }
                } footer: {
                    Text(Strings.sendToTelegramDesc)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 460, height: 580)
        .onAppear {
            if let task {
                name = task.name
                type = task.type
                hour = task.hour
                minute = task.minute
                weekdays = task.weekdays
                countdownMinutes = task.countdownMinutes
                intervalMinutes = task.intervalMinutes
                durationMinutes = task.durationMinutes
                telegramSend = task.telegramSend
            }
        }
    }

    private var weekdayToggles: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let isSelected = weekdays.contains(day)
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        if isSelected { weekdays.remove(day) }
                        else { weekdays.insert(day) }
                    }
                } label: {
                    Text(Strings.weekdays[day - 1])
                        .font(.caption.weight(.medium))
                        .frame(width: 38, height: 38)
                        .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save() {
        var t = task ?? ScheduledTask()
        t.name = name
        t.type = type
        t.hour = hour
        t.minute = minute
        t.weekdays = weekdays
        t.countdownMinutes = countdownMinutes
        t.intervalMinutes = intervalMinutes
        t.durationMinutes = durationMinutes
        t.telegramSend = telegramSend
        onSave(t)
        dismiss()
    }
}
