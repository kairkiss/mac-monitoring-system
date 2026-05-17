import Foundation

enum LogLevel: String, Codable, CaseIterable {
    case info
    case warning
    case error
    case success
}

enum LogCategory: String, Codable, CaseIterable {
    case camera
    case automation
    case telegram
    case media
    case storage
    case system
    case security
    case motion
    case health
    case notification
}

struct ActivityLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    var detail: String?
    var relatedFile: String?
    var taskID: String?
    var taskName: String?
}

final class ActivityLogManager: ObservableObject {
    static let shared = ActivityLogManager()

    @Published var entries: [ActivityLogEntry] = []

    private let maxEntries = 5000
    private let queue = DispatchQueue(label: "activity.log.queue", qos: .utility)
    private var fileURL: URL {
        MediaLibraryManager.shared.baseDirectory.appendingPathComponent("activity_log.jsonl")
    }

    private init() {
        loadEntries()
    }

    // MARK: - Logging

    func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        detail: String? = nil,
        relatedFile: String? = nil,
        taskID: String? = nil,
        taskName: String? = nil
    ) {
        let entry = ActivityLogEntry(
            id: UUID(),
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            detail: detail,
            relatedFile: relatedFile,
            taskID: taskID,
            taskName: taskName
        )

        queue.async { [weak self] in
            self?.appendEntry(entry)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries.insert(entry, at: 0)
            if self.entries.count > self.maxEntries {
                self.entries = Array(self.entries.prefix(self.maxEntries))
            }
        }
    }

    // Convenience methods
    func info(_ category: LogCategory, _ message: String, detail: String? = nil) {
        log(level: .info, category: category, message: message, detail: detail)
    }

    func warning(_ category: LogCategory, _ message: String, detail: String? = nil) {
        log(level: .warning, category: category, message: message, detail: detail)
    }

    func error(_ category: LogCategory, _ message: String, detail: String? = nil) {
        log(level: .error, category: category, message: message, detail: detail)
    }

    func success(_ category: LogCategory, _ message: String, detail: String? = nil) {
        log(level: .success, category: category, message: message, detail: detail)
    }

    // MARK: - Persistence

    private static let jsonEncoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys]
        return enc
    }()

    private static let jsonDecoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    private func appendEntry(_ entry: ActivityLogEntry) {
        guard let data = try? Self.jsonEncoder.encode(entry),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        guard let lineData = line.data(using: .utf8) else { return }

        let fm = FileManager.default
        let url = fileURL

        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        handle.write(lineData)
        handle.closeFile()

        trimFileIfNeeded()
    }

    private func loadEntries() {
        queue.async { [weak self] in
            guard let self else { return }
            guard let data = try? String(contentsOf: self.fileURL, encoding: .utf8) else { return }
            let lines = data.components(separatedBy: "\n").filter { !$0.isEmpty }
            var loaded: [ActivityLogEntry] = []
            for line in lines.suffix(2000) {
                if let entry = self.decodeLine(line) {
                    loaded.append(entry)
                }
            }
            loaded.sort { $0.timestamp > $1.timestamp }
            DispatchQueue.main.async {
                self.entries = loaded
            }
        }
    }

    /// Try standard JSONL first, fall back to base64-encoded JSON for backward compatibility.
    private func decodeLine(_ line: String) -> ActivityLogEntry? {
        if let lineData = line.data(using: .utf8),
           let entry = try? Self.jsonDecoder.decode(ActivityLogEntry.self, from: lineData) {
            return entry
        }
        if let base64Data = Data(base64Encoded: line),
           let entry = try? JSONDecoder().decode(ActivityLogEntry.self, from: base64Data) {
            return entry
        }
        return nil
    }

    private func trimFileIfNeeded() {
        guard let data = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        let lines = data.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > maxEntries else { return }
        let trimmed = lines.suffix(maxEntries)
        let output = trimmed.joined(separator: "\n") + "\n"
        try? output.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Actions

    func clearAll() {
        queue.async { [weak self] in
            guard let self else { return }
            try? Data().write(to: self.fileURL)
        }
        DispatchQueue.main.async { [weak self] in
            self?.entries.removeAll()
        }
    }

    func exportAsText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return entries.map { entry in
            let time = formatter.string(from: entry.timestamp)
            let level = entry.level.rawValue.uppercased()
            let cat = entry.category.rawValue
            var line = "[\(time)] [\(level)] [\(cat)] \(entry.message)"
            if let detail = entry.detail { line += " — \(detail)" }
            if let file = entry.relatedFile { line += " (file: \(file))" }
            if let task = entry.taskName { line += " (task: \(task))" }
            return line
        }.joined(separator: "\n")
    }

    func exportAsJSONL() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return entries.reversed().compactMap { entry in
            try? encoder.encode(entry)
        }.compactMap { String(data: $0, encoding: .utf8) }
        .joined(separator: "\n")
    }
}
