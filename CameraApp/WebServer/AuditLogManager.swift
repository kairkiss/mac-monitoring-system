import Foundation

struct AuditLogEntry: Codable {
    let timestamp: Date
    let method: String
    let path: String
    let status: Int
    let duration: TimeInterval
    let remoteAddress: String
    let user: String?
}

final class AuditLogManager {
    static let shared = AuditLogManager()

    private var logFileURL: URL {
        MediaLibraryManager.shared.baseDirectory.appendingPathComponent("audit_log.jsonl")
    }

    private let queue = DispatchQueue(label: "audit.log", qos: .utility)

    private init() {}

    func log(method: String, path: String, status: Int, duration: TimeInterval, remoteAddress: String, user: String?) {
        let entry = AuditLogEntry(
            timestamp: Date(),
            method: method,
            path: path,
            status: status,
            duration: duration,
            remoteAddress: remoteAddress,
            user: user
        )

        queue.async { [weak self] in
            guard let self, let data = try? JSONEncoder().encode(entry) else { return }
            var line = Data(data)
            line.append(Data("\n".utf8))

            let url = self.logFileURL
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(line)
                    handle.closeFile()
                }
            } else {
                try? line.write(to: url)
            }
        }
    }

    func readEntries(limit: Int = 100) -> [AuditLogEntry] {
        guard let data = try? Data(contentsOf: logFileURL),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return lines.suffix(limit).compactMap { line in
            guard let lineData = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(AuditLogEntry.self, from: lineData)
        }
    }

    func clear() {
        try? Data().write(to: logFileURL)
    }
}
