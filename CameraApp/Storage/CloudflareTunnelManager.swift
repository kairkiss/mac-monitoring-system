import Foundation

enum TunnelStatus: String {
    case stopped
    case starting
    case running
    case stopping
    case error
}

final class CloudflareTunnelManager: ObservableObject {
    static let shared = CloudflareTunnelManager()

    @Published private(set) var status: TunnelStatus = .stopped
    @Published private(set) var lastOutput: String = ""
    @Published private(set) var lastError: String = ""

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

        // Check configured path first
        let configured = settings.cloudflaredPath
        if !configured.isEmpty && FileManager.default.isExecutableFile(atPath: configured) {
            if let version = getVersion(at: configured) {
                return (true, configured, version)
            }
        }

        // Check common paths
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                if let version = getVersion(at: path) {
                    return (true, path, version)
                }
            }
        }

        // Try which
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

    func startTunnel() {
        let tunnelName = settings.cloudflareTunnelName
        let hostname = settings.cloudflareHostname
        let localPort = settings.webServerPort

        guard !tunnelName.isEmpty else {
            lastError = "Tunnel name not configured"
            status = .error
            return
        }

        let detection = detectCloudflared()
        guard detection.detected, let path = detection.path else {
            lastError = "cloudflared not found"
            status = .error
            return
        }

        // Save detected path
        if settings.cloudflaredPath != path {
            settings.cloudflaredPath = path
        }

        status = .starting
        lastError = ""
        lastOutput = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)

        var args = ["tunnel", "run"]
        if !hostname.isEmpty {
            args += ["--url", "http://127.0.0.1:\(localPort)"]
        }
        args.append(tunnelName)
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
                    // Check for connection established
                    if str.contains("Registered connection") || str.contains("connection established") {
                        self?.status = .running
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

        // SIGTERM first
        proc.terminate()

        // Wait 5s, then SIGKILL
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, let proc = self.process, proc.isRunning else { return }
            proc.interrupt() // SIGKILL equivalent for Process
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
        guard !settings.cloudflareTunnelName.isEmpty else { return }
        guard !isRunning else { return }
        startTunnel()
    }

    // MARK: - Helpers

    private func getVersion(at path: String) -> String? {
        let result = shell("\(path) --version")
        guard !result.isEmpty else { return nil }
        // Parse "cloudflared version 2024.1.0"
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
