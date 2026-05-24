import Foundation

enum TunnelStatus: String {
    case stopped
    case starting
    case running
    case stopping
    case error
}

enum TunnelMode: String, Codable {
    case quick    // cloudflared tunnel --url (temporary URL)
    case named    // cloudflared tunnel run <name> (persistent domain)
}

final class CloudflareTunnelManager: ObservableObject {
    static let shared = CloudflareTunnelManager()

    @Published private(set) var status: TunnelStatus = .stopped
    @Published private(set) var lastOutput: String = ""
    @Published private(set) var lastError: String = ""
    @Published private(set) var quickTunnelURL: String = ""

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private let settings = SettingsStore.shared

    private init() {}

    // MARK: - Public API

    func detectCloudflared() -> (detected: Bool, path: String?, version: String?) {
        let candidates = [
            "/usr/local/bin/cloudflared",
            "/opt/homebrew/bin/cloudflared",
            "/usr/bin/cloudflared"
        ]

        let configured = settings.cloudflaredPath
        if !configured.isEmpty && FileManager.default.isExecutableFile(atPath: configured) {
            if let version = getVersion(at: configured) {
                return (true, configured, version)
            }
        }

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                if let version = getVersion(at: path) {
                    return (true, path, version)
                }
            }
        }

        let whichResult = shell("which cloudflared")
        if !whichResult.isEmpty {
            let trimmed = whichResult.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.isExecutableFile(atPath: trimmed) {
                if let version = getVersion(at: trimmed) {
                    return (true, trimmed, version)
                }
            }
        }

        return (false, nil, nil)
    }

    func startTunnel(mode: TunnelMode? = nil) {
        let effectiveMode = mode ?? settings.cloudflareTunnelMode
        let localPort = settings.webServerPort

        let detection = detectCloudflared()
        guard detection.detected, let path = detection.path else {
            lastError = "cloudflared not found"
            status = .error
            return
        }

        if settings.cloudflaredPath != path {
            settings.cloudflaredPath = path
        }

        status = .starting
        lastError = ""
        lastOutput = ""
        quickTunnelURL = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)

        var args: [String]
        switch effectiveMode {
        case .quick:
            args = ["tunnel", "--url", "http://127.0.0.1:\(localPort)"]
        case .named:
            let tunnelName = settings.cloudflareTunnelName
            guard !tunnelName.isEmpty else {
                lastError = "Tunnel name not configured"
                status = .error
                return
            }
            args = ["tunnel", "run"]
            let hostname = settings.cloudflareHostname
            if !hostname.isEmpty {
                args += ["--url", "http://127.0.0.1:\(localPort)"]
            }
            args.append(tunnelName)
        }

        proc.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.lastOutput += str
                    if str.contains("Registered connection") || str.contains("connection established") {
                        self?.status = .running
                    }
                    // Parse quick tunnel URL
                    if let url = self?.parseQuickTunnelURL(from: str) {
                        self?.quickTunnelURL = url
                    }
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.lastOutput += str
                    // Quick tunnel URL often appears on stderr
                    if let url = self?.parseQuickTunnelURL(from: str) {
                        self?.quickTunnelURL = url
                    }
                    if str.lowercased().contains("error") || str.lowercased().contains("failed") {
                        self?.lastError = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        proc.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.status == .running || self.status == .starting {
                    self.status = .stopped
                }
                if process.terminationStatus != 0 && !self.lastError.isEmpty {
                    self.status = .error
                }
                self.process = nil
                self.outputPipe = nil
                self.errorPipe = nil
            }
        }

        do {
            try proc.run()
            process = proc
            outputPipe = outPipe
            errorPipe = errPipe
        } catch {
            lastError = "Failed to start: \(error.localizedDescription)"
            status = .error
        }
    }

    func stopTunnel() {
        guard let proc = process, proc.isRunning else {
            status = .stopped
            return
        }

        status = .stopping
        proc.terminate()

        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, let proc = self.process, proc.isRunning else { return }
            proc.interrupt()
        }
    }

    var isRunning: Bool {
        guard let proc = process else { return false }
        return proc.isRunning && status == .running
    }

    var pid: Int32? {
        guard let proc = process, proc.isRunning else { return nil }
        return proc.processIdentifier
    }

    func autoStartIfNeeded() {
        guard settings.cloudflareAutoStart else { return }
        guard !isRunning else { return }

        let mode = settings.cloudflareTunnelMode
        switch mode {
        case .quick:
            startTunnel(mode: .quick)
        case .named:
            guard !settings.cloudflareTunnelName.isEmpty else { return }
            startTunnel(mode: .named)
        }
    }

    func diagnostics() -> [String: String] {
        let detection = detectCloudflared()
        var diag: [String: String] = [:]
        diag["cloudflaredDetected"] = detection.detected ? "Yes" : "No"
        diag["cloudflaredPath"] = detection.path ?? "Not found"
        diag["cloudflaredVersion"] = detection.version ?? "Unknown"
        diag["tunnelMode"] = settings.cloudflareTunnelMode.rawValue
        diag["tunnelStatus"] = status.rawValue
        diag["tunnelName"] = settings.cloudflareTunnelName
        diag["hostname"] = settings.cloudflareHostname
        diag["pid"] = pid.map { String($0) } ?? "N/A"
        if !quickTunnelURL.isEmpty {
            diag["quickTunnelURL"] = quickTunnelURL
        }
        return diag
    }

    // MARK: - Helpers

    private func parseQuickTunnelURL(from text: String) -> String? {
        // Quick tunnel outputs: "Your quick Tunnel has been created! Visit it at https://xxx.trycloudflare.com"
        let pattern = "https?://[a-zA-Z0-9\\-]+\\.trycloudflare\\.com"
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }

    private func getVersion(at path: String) -> String? {
        let result = shell("\(path) --version")
        guard !result.isEmpty else { return nil }
        let parts = result.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
        if parts.count >= 3 {
            return parts.last
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shell(_ command: String) -> String {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", command]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
