import SwiftUI

struct ActivityLogView: View {
    @StateObject private var logManager = ActivityLogManager.shared
    @State private var levelFilter: LogLevel?
    @State private var categoryFilter: LogCategory?
    @State private var searchText = ""
    @State private var showClearConfirm = false

    private var filteredEntries: [ActivityLogEntry] {
        logManager.entries.filter { entry in
            if let level = levelFilter, entry.level != level { return false }
            if let category = categoryFilter, entry.category != category { return false }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                return entry.message.lowercased().contains(query)
                    || entry.detail?.lowercased().contains(query) == true
                    || entry.taskName?.lowercased().contains(query) == true
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filters
            HStack(spacing: 12) {
                Picker("Level", selection: $levelFilter) {
                    Text("All Levels").tag(nil as LogLevel?)
                    Divider()
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Label(level.rawValue.capitalized, systemImage: levelIcon(level))
                            .tag(level as LogLevel?)
                    }
                }
                .frame(width: 130)

                Picker("Category", selection: $categoryFilter) {
                    Text("All Categories").tag(nil as LogCategory?)
                    Divider()
                    ForEach(LogCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue.capitalized).tag(cat as LogCategory?)
                    }
                }
                .frame(width: 150)

                Spacer()

                Button {
                    copyLog()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Menu {
                    Button("Export as .txt") { exportLog(as: .txt) }
                    Button("Export as .jsonl") { exportLog(as: .jsonl) }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 80)

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider()

            // Log list
            if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No log entries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredEntries) { entry in
                    logRow(entry)
                }
                .listStyle(.plain)
            }

            // Status bar
            HStack {
                Text("\(filteredEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Activity Log")
        .searchable(text: $searchText, prompt: "Search logs...")
        .alert("Clear All Logs", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                logManager.clearAll()
            }
        } message: {
            Text("This will permanently delete all activity log entries.")
        }
    }

    private func logRow(_ entry: ActivityLogEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Level indicator
            Circle()
                .fill(levelColor(entry.level))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.message)
                        .font(.subheadline)
                        .lineLimit(2)
                    Spacer()
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    Text(entry.category.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())

                    if let taskName = entry.taskName {
                        Text(taskName)
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }

                    if let detail = entry.detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func levelIcon(_ level: LogLevel) -> String {
        switch level {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .success: return "checkmark.circle"
        }
    }

    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }

    private func copyLog() {
        let text = logManager.exportAsText()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private enum ExportFormat { case txt, jsonl }

    private func exportLog(as format: ExportFormat) {
        let panel = NSSavePanel()
        switch format {
        case .txt:
            panel.nameFieldStringValue = "activity_log.txt"
            panel.allowedContentTypes = [.plainText]
        case .jsonl:
            panel.nameFieldStringValue = "activity_log.jsonl"
            panel.allowedContentTypes = [.json]
        }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let content = format == .txt ? logManager.exportAsText() : logManager.exportAsJSONL()
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
