import Foundation

enum TunnelStatus: String {
    case stopped
    case starting
    case running
    case stopping
    case restarting
    case error
}

enum TunnelMode: String, Codable {
    case quick    // cloudflared tunnel --url (temporary URL)
    case named    // cloudflared tunnel run <name> (persistent domain)
}

enum CloudflareSetupStatus: String {
    case notInstalled           // cloudflared binary not found
    case installedNotLoggedIn   // binary found, no credentials
    case loggedInNoTunnel       // credentials exist, no tunnel name configured
    case tunnelNameMissing      // named mode but tunnel name empty
    case hostnameMissing        // named mode but hostname empty
    case configMissing          // config.yml doesn't exist
    case configInvalid          // config.yml exists but can't be parsed
    case credentialsMissing     // no .json credentials in ~/.cloudflared
    case ingressMismatch        // config service port doesn't match web server port
    case ready                  // everything configured, ready to start
    case running                // tunnel is currently running
    case error                  // error state

    var displayName: String {
        switch self {
        case .notInstalled: return "cloudflared not installed"
        case .installedNotLoggedIn: return "Not logged in to Cloudflare"
        case .loggedInNoTunnel: return "No tunnel configured"
        case .tunnelNameMissing: return "Tunnel name missing"
        case .hostnameMissing: return "Hostname missing"
        case .configMissing: return "config.yml not found"
        case .configInvalid: return "config.yml invalid"
        case .credentialsMissing: return "Credentials missing"
        case .ingressMismatch: return "Service port mismatch"
        case .ready: return "Ready to start"
        case .running: return "Running"
        case .error: return "Error"
        }
    }
}

struct CloudflareConfig {
    var tunnel: String = ""
    var credentialsFile: String = ""
    var ingressHostname: String = ""
    var ingressService: String = ""  // e.g. "http://127.0.0.1:8765"

    var parsedServicePort: Int? {
        // Extract port from "http://127.0.0.1:8765" or "http://localhost:8765"
        guard let range = ingressService.range(of: ":", options: .backwards) else { return nil }
        let portStr = ingressService[range.upperBound...]
        return Int(portStr)
    }
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

    // Intent flags — distinguish user action from unexpected process exit
    private var isUserStopping = false
    private var isRestartingFlow = false

    // Timeout work items so we can cancel them
    private var startupTimeoutWork: DispatchWorkItem?
    private var stopTimeoutWork: DispatchWorkItem?

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

        // Prevent duplicate processes — kill existing one first
        if let existingProc = process, existingProc.isRunning {
            isUserStopping = true
            existingProc.terminate()
            // Give it a moment to die, then continue with start
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.isUserStopping = false
                self?.process = nil
                self?.startTunnel(mode: effectiveMode)
            }
            return
        }

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
        isUserStopping = false

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
            let config = detectCloudflaredConfig()
            if !config.credentialsExist {
                lastError = "No credentials found in ~/.cloudflared/. Run 'cloudflared tunnel login' first."
                status = .error
                return
            }
            args = ["tunnel", "run", tunnelName]
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
                    self?.checkForRunningSignal(str)
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.lastOutput += str
                    self?.checkForRunningSignal(str)
                    if str.lowercased().contains("error") || str.lowercased().contains("failed") {
                        self?.lastError = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        proc.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self else { return }
                // Cancel any pending timeout checks
                self.startupTimeoutWork?.cancel()
                self.startupTimeoutWork = nil
                self.stopTimeoutWork?.cancel()
                self.stopTimeoutWork = nil

                let exitCode = process.terminationStatus

                // If user explicitly stopped or we're in restart flow → .stopped
                if self.isUserStopping || self.isRestartingFlow {
                    self.status = .stopped
                    self.isUserStopping = false
                    // Don't reset isRestartingFlow here — restartTunnel handles it
                } else if self.status == .stopping {
                    // terminationHandler caught the stop
                    self.status = .stopped
                } else if self.status == .running || self.status == .starting {
                    // Unexpected exit while running or starting
                    if exitCode != 0 {
                        self.status = .error
                        if self.lastError.isEmpty {
                            self.lastError = "Process exited with code \(exitCode)"
                        }
                    } else {
                        self.status = .stopped
                    }
                } else {
                    // Fallback: any other state → stopped
                    self.status = .stopped
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

            // Startup timeout: if still in .starting after 10s, check if process is alive
            // and assume running (cloudflared may output to a stream we're not reading)
            let timeout10 = DispatchWorkItem { [weak self] in
                DispatchQueue.main.async {
                    guard let self, self.status == .starting else { return }
                    if let proc = self.process, proc.isRunning {
                        // Process is alive but we never detected a running signal — assume running
                        self.status = .running
                    }
                }
            }
            startupTimeoutWork = timeout10
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout10)
        } catch {
            lastError = "Failed to start: \(error.localizedDescription)"
            status = .error
        }
    }

    func stopTunnel() {
        guard let proc = process, proc.isRunning else {
            status = .stopped
            process = nil
            outputPipe = nil
            errorPipe = nil
            return
        }

        isUserStopping = true
        status = .stopping
        proc.terminate()

        // Escalate to interrupt after 5s if still alive
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, let proc = self.process, proc.isRunning else { return }
            proc.interrupt()
        }

        // Stop timeout: if still in .stopping after 8s, force reset
        let timeout8 = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.status == .stopping else { return }
                self.forceStop()
            }
        }
        stopTimeoutWork = timeout8
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout8)
    }

    func restartTunnel(mode: TunnelMode? = nil) {
        let effectiveMode = mode ?? settings.cloudflareTunnelMode
        guard status != .restarting else { return }

        isRestartingFlow = true
        status = .restarting
        lastError = ""

        // Stop if running
        if let proc = process, proc.isRunning {
            isUserStopping = true
            proc.terminate()
        }

        // Wait for process to exit, then start
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            // Force kill if still running
            if let proc = self.process, proc.isRunning {
                proc.interrupt()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                self.isUserStopping = false
                self.isRestartingFlow = false
                self.process = nil
                self.outputPipe = nil
                self.errorPipe = nil
                self.startTunnel(mode: effectiveMode)
                ActivityLogManager.shared.info(.webServer, "Tunnel restarted: mode=\(effectiveMode.rawValue)")
            }
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

    func detectCloudflaredConfig() -> (configExists: Bool, credentialsExist: Bool, config: CloudflareConfig?) {
        let configPath = configFilePath()
        let cloudflaredDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cloudflared")
        let configExists = FileManager.default.fileExists(atPath: configPath.path)

        var credentialsExist = false
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: cloudflaredDir.path) {
            credentialsExist = contents.contains { $0.hasSuffix(".json") }
        }

        var config: CloudflareConfig? = nil
        if configExists {
            config = parseConfigYML(at: configPath)
        }

        return (configExists, credentialsExist, config)
    }

    func configFilePath() -> URL {
        let custom = settings.cloudflareConfigPath
        if !custom.isEmpty {
            return URL(fileURLWithPath: custom)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cloudflared")
            .appendingPathComponent("config.yml")
    }

    func parseConfigYML(at url: URL) -> CloudflareConfig? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var config = CloudflareConfig()
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") || trimmed.isEmpty { continue }
            // Simple key: value parsing (no nested YAML)
            let parts = trimmed.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let key = parts[0]
            let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            switch key {
            case "tunnel": config.tunnel = value
            case "credentials-file": config.credentialsFile = value
            case "hostname": config.ingressHostname = value
            case "service": config.ingressService = value
            default: break
            }
        }
        return config
    }

    func generateConfigYML() -> String {
        let tunnelName = settings.cloudflareTunnelName
        let hostname = settings.cloudflareHostname
        let port = settings.webServerPort
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let credFile = "\(home)/.cloudflared/\(tunnelName).json"

        return """
        tunnel: \(tunnelName)
        credentials-file: \(credFile)

        ingress:
          - hostname: \(hostname)
            service: http://127.0.0.1:\(port)
          - service: http_status:404
        """
    }

    func writeConfigWithBackup(content: String) -> (ok: Bool, error: String?, backupPath: String?) {
        let url = configFilePath()
        let fm = FileManager.default
        var backupPath: String? = nil

        // Backup existing config
        if fm.fileExists(atPath: url.path) {
            let backup = url.appendingPathExtension("bak.\(Int(Date().timeIntervalSince1970))")
            do {
                try fm.copyItem(at: url, to: backup)
                backupPath = backup.path
            } catch {
                // Non-fatal, continue with write
            }
        }

        // Ensure directory exists
        let dir = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return (true, nil, backupPath)
        } catch {
            return (false, error.localizedDescription, backupPath)
        }
    }

    func setupStatus() -> (status: CloudflareSetupStatus, config: CloudflareConfig?, details: [String: String]) {
        var details: [String: String] = [:]
        let detection = detectCloudflared()

        guard detection.detected else {
            return (.notInstalled, nil, details)
        }
        details["cloudflaredPath"] = detection.path
        details["cloudflaredVersion"] = detection.version

        let configResult = detectCloudflaredConfig()
        details["configExists"] = configResult.configExists ? "true" : "false"
        details["credentialsExist"] = configResult.credentialsExist ? "true" : "false"

        // Quick mode doesn't need most checks
        if settings.cloudflareTunnelMode == .quick {
            if self.status == .running {
                return (.running, configResult.config, details)
            }
            return (.ready, configResult.config, details)
        }

        // Named mode checks
        guard configResult.credentialsExist else {
            return (.credentialsMissing, configResult.config, details)
        }

        guard !settings.cloudflareTunnelName.isEmpty else {
            return (.tunnelNameMissing, configResult.config, details)
        }

        guard !settings.cloudflareHostname.isEmpty else {
            return (.hostnameMissing, configResult.config, details)
        }

        guard configResult.configExists else {
            return (.configMissing, configResult.config, details)
        }

        guard let config = configResult.config else {
            return (.configInvalid, nil, details)
        }

        details["configTunnel"] = config.tunnel
        details["configHostname"] = config.ingressHostname
        details["configService"] = config.ingressService

        // Validate config matches settings
        if config.tunnel != settings.cloudflareTunnelName {
            details["configWarning"] = "Config tunnel '\(config.tunnel)' doesn't match setting '\(settings.cloudflareTunnelName)'"
        }

        // Check service port matches web server port
        if let configPort = config.parsedServicePort, configPort != settings.webServerPort {
            return (.ingressMismatch, config, details)
        }

        if self.status == .running {
            return (.running, config, details)
        }

        return (.ready, config, details)
    }

    func diagnostics() -> [String: String] {
        let detection = detectCloudflared()
        let configResult = detectCloudflaredConfig()
        let setup = setupStatus()
        var diag: [String: String] = [:]
        diag["cloudflaredDetected"] = detection.detected ? "Yes" : "No"
        diag["cloudflaredPath"] = detection.path ?? "Not found"
        diag["cloudflaredVersion"] = detection.version ?? "Unknown"
        diag["configExists"] = configResult.configExists ? "Yes" : "No"
        diag["credentialsExist"] = configResult.credentialsExist ? "Yes" : "No"
        diag["setupStatus"] = setup.status.rawValue
        diag["setupStatusDisplay"] = setup.status.displayName
        if let config = setup.config {
            diag["configTunnel"] = config.tunnel
            diag["configHostname"] = config.ingressHostname
            diag["configService"] = config.ingressService
        }
        for (k, v) in setup.details {
            diag[k] = v
        }
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

    // MARK: - State Machine Helpers

    /// Check log output for signals that the tunnel is running.
    private func checkForRunningSignal(_ str: String) {
        guard status == .starting || status == .restarting else { return }

        // Quick tunnel URL detection → tunnel is running
        if let url = parseQuickTunnelURL(from: str) {
            quickTunnelURL = url
            status = .running
            startupTimeoutWork?.cancel()
            startupTimeoutWork = nil
            return
        }

        // Named tunnel running signals (stdout and stderr)
        let runningSignals = [
            "Registered connection",
            "connection established",
            "Connection registered",
            "connIndex",
            "Starting tunnel",
            "Tunnel started",
            "INF Connection registered"
        ]
        for signal in runningSignals {
            if str.contains(signal) {
                status = .running
                startupTimeoutWork?.cancel()
                startupTimeoutWork = nil
                return
            }
        }
    }

    /// Force reset to stopped state — kills process if alive, clears all state.
    func forceStop() {
        // Cancel timeouts
        startupTimeoutWork?.cancel()
        startupTimeoutWork = nil
        stopTimeoutWork?.cancel()
        stopTimeoutWork = nil

        // Kill process if still alive
        if let proc = process {
            if proc.isRunning {
                proc.terminate()
                // Give it 1s then force kill
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self, let p = self.process, p.isRunning else { return }
                    p.interrupt()
                    DispatchQueue.main.async {
                        self.process = nil
                        self.outputPipe = nil
                        self.errorPipe = nil
                        self.status = .stopped
                        self.isUserStopping = false
                        self.isRestartingFlow = false
                    }
                }
                return
            }
        }

        process = nil
        outputPipe = nil
        errorPipe = nil
        status = .stopped
        isUserStopping = false
        isRestartingFlow = false
    }

    /// Check the real process state and correct the UI status if it's stale.
    func reconcileStatus() {
        let realRunning = process?.isRunning ?? false

        if realRunning && (status == .stopped || status == .error) {
            // Process is alive but UI says stopped — fix it
            status = .running
        } else if !realRunning && (status == .running || status == .starting || status == .stopping) {
            // Process is dead but UI says running/starting/stopping — fix it
            startupTimeoutWork?.cancel()
            startupTimeoutWork = nil
            stopTimeoutWork?.cancel()
            stopTimeoutWork = nil
            process = nil
            outputPipe = nil
            errorPipe = nil
            status = .stopped
            isUserStopping = false
            isRestartingFlow = false
        }
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
