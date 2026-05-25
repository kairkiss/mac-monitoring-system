import SwiftUI

struct CloudflareControlPanelView: View {
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject private var tunnel = CloudflareTunnelManager.shared

    @State private var cloudflaredDetected = false
    @State private var cloudflaredPath = ""
    @State private var cfSetupStatus: CloudflareSetupStatus = .notInstalled
    @State private var cfDiagnostics: [String: String] = [:]
    @State private var cfConfigPreview = ""
    @State private var cfShowConfigPreview = false
    @State private var cfWriteConfirm = false
    @State private var cfWriteResult = ""
    @State private var cfCopiedToast = ""
    @State private var cfShowOutput = false
    @State private var isRefreshing = false

    var body: some View {
        Section {
            // Status badge
            statusBadge

            // Primary action buttons
            startButtons
            controlButtons

            // Public URL
            publicURLDisplay

            // Toasts
            if !cfCopiedToast.isEmpty {
                Text("✓ \(cfCopiedToast)").font(.caption).foregroundStyle(.green)
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { cfCopiedToast = "" } }
            }
            if !cfWriteResult.isEmpty {
                Text(cfWriteResult).font(.caption).foregroundStyle(cfWriteResult.contains("Error") ? .red : .green)
            }

            // Last error
            if !tunnel.lastError.isEmpty {
                Label(tunnel.lastError, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red)
                    .lineLimit(3)
            }

            // Setup hint
            if cfSetupStatus != .ready && cfSetupStatus != .running {
                setupHint
            }

            // Configuration (collapsible)
            DisclosureGroup {
                Picker(Strings.tunnelMode, selection: $settings.cloudflareTunnelMode) {
                    Text(Strings.quickTunnel).tag(TunnelMode.quick)
                    Text(Strings.namedTunnel).tag(TunnelMode.named)
                }
                .onChange(of: settings.cloudflareTunnelMode) { _, _ in refreshStatus() }

                cloudflaredInfoRow
                localURLRow

                if settings.cloudflareTunnelMode == .named {
                    namedConfigFields
                    configActionButtons
                    if cfShowConfigPreview {
                        configPreviewView
                    }
                }
            } label: {
                Label("Configuration", systemImage: "gearshape")
            }

            // Diagnostics (collapsible)
            DisclosureGroup(Strings.tunnelDiagnostics, isExpanded: $cfShowOutput) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tunnel.lastOutput.isEmpty ? "—" : String(tunnel.lastOutput.suffix(1000)))
                        .font(.caption.monospaced()).foregroundStyle(.tertiary)
                        .lineLimit(20)
                }
            }
        } header: {
            Label(Strings.cfControlPanel, systemImage: "network.badge.shield.half.filled")
        }
        .onAppear { refreshStatus() }
        .alert(Strings.cfWriteConfirmTitle, isPresented: $cfWriteConfirm) {
            Button(Strings.cancel, role: .cancel) { }
            Button(Strings.cfWriteConfig, role: .destructive) {
                let result = CloudflareTunnelManager.shared.writeConfigWithBackup(content: CloudflareTunnelManager.shared.generateConfigYML())
                if result.ok {
                    var msg = Strings.cfConfigWritten
                    if let backup = result.backupPath {
                        msg += " (backup: \(backup))"
                    }
                    cfWriteResult = msg
                    ActivityLogManager.shared.info(.webServer, "Config.yml written from App UI")
                    refreshStatus()
                } else {
                    cfWriteResult = "Error: \(result.error ?? "unknown")"
                }
            }
        } message: {
            let path = CloudflareTunnelManager.shared.configFilePath().path
            Text("\(Strings.cfWriteConfirmMsg)\n\nPath: \(path)\nTunnel: \(settings.cloudflareTunnelName)\nHostname: \(settings.cloudflareHostname)\nService: http://127.0.0.1:\(settings.webServerPort)")
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        let color: Color = {
            switch tunnel.status {
            case .running: return .green
            case .starting, .restarting: return .orange
            case .stopping: return .yellow
            case .error: return .red
            case .stopped: return .secondary
            }
        }()
        let text: String = {
            switch tunnel.status {
            case .running: return Strings.cfTunnelRunning
            case .starting: return Strings.cloudflareStarting
            case .restarting: return Strings.cfTunnelRestarting
            case .stopping: return "Stopping..."
            case .error: return Strings.cloudflareError
            case .stopped: return Strings.cfTunnelStopped
            }
        }()
        return HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text).font(.subheadline).fontWeight(.medium)
            if tunnel.status == .running, settings.cloudflareTunnelMode == .named, !settings.cloudflareHostname.isEmpty {
                Text("— \(settings.cloudflareHostname)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let pid = tunnel.pid {
                Text("PID: \(pid)").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Start Buttons

    private var startButtons: some View {
        let isRunning = tunnel.status == .running
        let isBusy = tunnel.status == .starting || tunnel.status == .restarting || tunnel.status == .stopping

        return HStack(spacing: 12) {
            Button {
                tunnel.startTunnel(mode: .quick); refreshAfterDelay()
            } label: {
                Label(Strings.cfStartQuick, systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(isRunning || isBusy || !cloudflaredDetected)

            Button {
                tunnel.startTunnel(mode: .named); refreshAfterDelay()
            } label: {
                Label(Strings.cfStartNamed, systemImage: "network.badge.shield.half.filled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(isRunning || isBusy || !cloudflaredDetected)
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        let isRunning = tunnel.status == .running
        let isBusy = tunnel.status == .starting || tunnel.status == .restarting || tunnel.status == .stopping

        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    tunnel.stopTunnel(); refreshAfterDelay()
                } label: {
                    Label(Strings.cfStopTunnel, systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!isRunning && tunnel.status != .starting)

                Button {
                    tunnel.restartTunnel(mode: settings.cloudflareTunnelMode); refreshAfterDelay(5)
                } label: {
                    Label(Strings.cfRestartTunnel, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(tunnel.status == .restarting || !cloudflaredDetected)

                Button {
                    refreshStatus()
                } label: {
                    Label(Strings.cfRefreshStatus, systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            // Emergency row: Force Stop and Reset Status
            if isBusy || tunnel.status == .error {
                HStack(spacing: 12) {
                    Button {
                        tunnel.forceStop()
                        refreshAfterDelay(1)
                    } label: {
                        Label("Force Stop", systemImage: "xmark.octagon.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button {
                        tunnel.reconcileStatus()
                        refreshStatus()
                    } label: {
                        Label("Reset Status", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Public URL

    private var publicURLDisplay: some View {
        let publicURL: String? = {
            if settings.cloudflareTunnelMode == .quick, !tunnel.quickTunnelURL.isEmpty {
                return tunnel.quickTunnelURL
            } else if settings.cloudflareTunnelMode == .named, !settings.cloudflareHostname.isEmpty {
                let host = settings.cloudflareHostname.trimmingCharacters(in: .whitespaces)
                if host.hasPrefix("http://") || host.hasPrefix("https://") {
                    return host
                }
                return "https://\(host)"
            }
            return nil
        }()

        return Group {
            if let url = publicURL, let safeURL = URL(string: url) {
                HStack {
                    Label(Strings.cfPublicURL, systemImage: "globe")
                        .fontWeight(.medium)
                    Spacer()
                    Link(url, destination: safeURL)
                        .font(.caption).lineLimit(1)
                    Button { copyToClipboard(url); cfCopiedToast = Strings.cfCopyPublicURL } label: {
                        Image(systemName: "doc.on.clipboard").font(.caption)
                    }.buttonStyle(.borderless)
                }
            } else if let url = publicURL {
                // URL exists but is not valid — show as text, no Link
                HStack {
                    Label(Strings.cfPublicURL, systemImage: "globe")
                        .fontWeight(.medium)
                    Spacer()
                    Text(url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Button { copyToClipboard(url); cfCopiedToast = Strings.cfCopyPublicURL } label: {
                        Image(systemName: "doc.on.clipboard").font(.caption)
                    }.buttonStyle(.borderless)
                }
            } else if settings.cloudflareTunnelMode == .quick && tunnel.status == .stopped {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle").foregroundStyle(.secondary)
                    Text("Start Quick Tunnel to get a public URL")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Cloudflared Info

    private var cloudflaredInfoRow: some View {
        HStack {
            Image(systemName: cloudflaredDetected ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(cloudflaredDetected ? .green : .red)
            Text(cloudflaredDetected ? Strings.cloudflaredDetected : Strings.cloudflaredNotDetected)
                .font(.caption)
            if let ver = cfDiagnostics["cloudflaredVersion"], ver != "Unknown" {
                Text("v\(ver)").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Local URL

    private var localURLRow: some View {
        HStack {
            Text(Strings.cfLocalURL).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("http://127.0.0.1:\(settings.webServerPort)")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
            Button { copyToClipboard("http://127.0.0.1:\(settings.webServerPort)"); cfCopiedToast = Strings.cfCopyLocalURL } label: {
                Image(systemName: "doc.on.clipboard").font(.caption)
            }.buttonStyle(.borderless)
        }
    }

    // MARK: - Named Config Fields

    private var namedConfigFields: some View {
        Group {
            TextField(Strings.cfTunnelName, text: $settings.cloudflareTunnelName)
                .textFieldStyle(.roundedBorder)
            TextField(Strings.cfPublicHostname, text: $settings.cloudflareHostname)
                .textFieldStyle(.roundedBorder)
            if let configTunnel = cfDiagnostics["configTunnel"], !configTunnel.isEmpty {
                HStack {
                    Text("Config service:").font(.caption).foregroundStyle(.secondary)
                    Text(cfDiagnostics["configService"] ?? "—").font(.caption.monospaced()).foregroundStyle(.secondary)
                    if cfSetupStatus == .ingressMismatch {
                        Text("≠ http://127.0.0.1:\(settings.webServerPort)").font(.caption).foregroundStyle(.red)
                    }
                }
            }
            HStack {
                Text("Credentials:").font(.caption).foregroundStyle(.secondary)
                Text(cfDiagnostics["credentialsExist"] == "true" ? "✓ Found" : "✗ Missing")
                    .font(.caption).foregroundStyle(cfDiagnostics["credentialsExist"] == "true" ? .green : .red)
            }
        }
    }

    // MARK: - Config Actions

    private var configActionButtons: some View {
        HStack(spacing: 8) {
            Button(Strings.cfGenerateConfig) {
                cfConfigPreview = CloudflareTunnelManager.shared.generateConfigYML()
                cfShowConfigPreview = true
            }
            .disabled(settings.cloudflareTunnelName.isEmpty || settings.cloudflareHostname.isEmpty)

            Button(Strings.cfCopyConfig) {
                copyToClipboard(CloudflareTunnelManager.shared.generateConfigYML())
                cfCopiedToast = Strings.cfCopyConfig
            }
            .disabled(settings.cloudflareTunnelName.isEmpty || settings.cloudflareHostname.isEmpty)

            Button(Strings.cfWriteConfig) { cfWriteConfirm = true }
                .disabled(settings.cloudflareTunnelName.isEmpty || settings.cloudflareHostname.isEmpty)

            Button(Strings.cfOpenConfigFolder) {
                NSWorkspace.shared.open(CloudflareTunnelManager.shared.configFilePath().deletingLastPathComponent())
            }
        }
    }

    // MARK: - Config Preview

    private var configPreviewView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("config.yml").font(.caption).fontWeight(.medium)
                Spacer()
                Button { copyToClipboard(cfConfigPreview); cfCopiedToast = Strings.cfCopyConfig } label: {
                    Image(systemName: "doc.on.clipboard").font(.caption)
                }.buttonStyle(.borderless)
            }
            ScrollView(.horizontal) {
                Text(cfConfigPreview)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 150)
            .padding(6)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(6)
        }
    }

    // MARK: - Setup Hint

    private var setupHint: some View {
        let hint: String = {
            switch cfSetupStatus {
            case .notInstalled: return Strings.cfStatusNotInstalled + " — brew install cloudflared"
            case .installedNotLoggedIn: return "cloudflared tunnel login"
            case .credentialsMissing: return Strings.cfStatusCredentialsMissing + " — cloudflared tunnel login"
            case .tunnelNameMissing: return Strings.cfStatusTunnelNameMissing
            case .hostnameMissing: return Strings.cfStatusHostnameMissing
            case .configMissing: return Strings.cfStatusConfigMissing + " — " + Strings.cfGenerateConfig
            case .ingressMismatch: return Strings.cfStatusIngressMismatch + " — " + Strings.cfGenerateConfig
            default: return ""
            }
        }()
        return Group {
            if !hint.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").foregroundStyle(.orange)
                    Text(Strings.cfSetupHint + hint).font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Refresh

    private func refreshStatus() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task.detached {
            let tunnel = CloudflareTunnelManager.shared
            tunnel.reconcileStatus()
            let detection = tunnel.detectCloudflared()
            let setup = tunnel.setupStatus()
            await MainActor.run {
                self.cloudflaredDetected = detection.detected
                self.cloudflaredPath = detection.path ?? ""
                self.cfSetupStatus = setup.status
                self.cfDiagnostics = setup.details
                self.isRefreshing = false
            }
        }
    }

    private func refreshAfterDelay(_ seconds: Double = 2) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { refreshStatus() }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
