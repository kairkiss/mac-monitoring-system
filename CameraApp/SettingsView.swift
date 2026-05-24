import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case overview
    case notifications
    case camera
    case storage
    case webRemote
    case automation
    case retention
    case advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return Strings.overviewSection
        case .notifications: return Strings.notificationsSection
        case .camera: return Strings.cameraSection
        case .storage: return Strings.storageCloudSection
        case .webRemote: return Strings.webRemoteSection
        case .automation: return Strings.automationSection
        case .retention: return "Retention"
        case .advanced: return Strings.advancedSection
        }
    }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .notifications: return "bell.fill"
        case .camera: return "camera.fill"
        case .storage: return "externaldrive.fill"
        case .webRemote: return "network"
        case .automation: return "clock.fill"
        case .retention: return "trash.fill"
        case .advanced: return "gearshape.fill"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var telegram: TelegramService
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var mediaLibrary: MediaLibraryManager
    @EnvironmentObject var automation: AutomationScheduler
    @State private var selectedSection: SettingsSection? = .overview
    @State private var cleanResult: Int?
    @State private var storageTestResult: Bool?
    @State private var webPassword: String = ""
    @State private var showWebPassword: Bool = false
    @State private var webUsername: String = ""
    @State private var webCredentialMessage: String?
    @State private var webCredentialIsError: Bool = false
    @State private var gdAuthMessage: String?
    @State private var gdAuthIsError: Bool = false
    @State private var cfCopiedMessage: String?
    @State private var gdClientSecret: String = ""
    @State private var storageDiagnostics: StorageDiagnostics?
    @State private var dryRunResult: RetentionDryRunResult?
    @State private var cloudflaredDetected: Bool = false
    @State private var cloudflaredPath: String = ""
    @State private var showTaskSheet: Bool = false
    @State private var editingTask: ScheduledTask?

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.label, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            Form {
                switch selectedSection {
                case .overview:
                    overviewSection
                case .notifications:
                    notificationsSection
                case .camera:
                    cameraSection
                case .storage:
                    storageSection
                case .webRemote:
                    webRemoteSection
                case .automation:
                    automationSection
                case .retention:
                    retentionSection
                case .advanced:
                    advancedSection
                case .none:
                    Text(Strings.settingsTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(selectedSection?.label ?? Strings.settingsTitle)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showTaskSheet) {
            TaskEditSheet(task: editingTask) { savedTask in
                if editingTask != nil {
                    if let idx = automation.tasks.firstIndex(where: { $0.id == savedTask.id }) {
                        automation.tasks[idx] = savedTask
                    }
                } else {
                    automation.tasks.append(savedTask)
                }
                automation.saveAllTasks()
                automation.rescheduleAll()
            }
        }
    }

    // MARK: - Overview Section

    @ViewBuilder
    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    Text(Strings.cameraTitle)
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(Strings.cameraRunning)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 24)
                    Text(Strings.automationSection)
                    Spacer()
                    Text(automation.isAutomationEnabled ? Strings.automationEnabled : Strings.automationDisabled)
                        .foregroundStyle(automation.isAutomationEnabled ? .green : .secondary)
                    Text("\(automation.tasks.filter { $0.isEnabled }.count) active")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Divider()

                HStack {
                    Image(systemName: "externaldrive.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 24)
                    Text(Strings.storageUsage)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: mediaLibrary.totalStorageBytes, countStyle: .file))
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Image(systemName: "photo.stack.fill")
                        .foregroundStyle(.green)
                        .frame(width: 24)
                    Text(Strings.photos)
                    Spacer()
                    Text("\(mediaLibrary.photos.count) photos, \(mediaLibrary.videos.count) videos")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                let pendingUploads = MediaIndexStore.shared.pendingUploadItems()
                if !pendingUploads.isEmpty {
                    Divider()
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.red)
                            .frame(width: 24)
                        Text(Strings.uploadQueue)
                        Spacer()
                        Text("\(pendingUploads.count) pending")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Notifications Section

    @ViewBuilder
    private var notificationsSection: some View {
        // Telegram Settings
        Section {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 20)
                SecureField(Strings.botToken, text: $settings.telegramBotToken)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                TextField(Strings.chatID, text: $settings.telegramChatID)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button {
                    telegram.sendTestPhoto()
                } label: {
                    if telegram.isSending {
                        ProgressView()
                            .controlSize(.small)
                        Text(Strings.testing)
                    } else {
                        Label(Strings.testSend, systemImage: "paperplane.fill")
                    }
                }
                .disabled(telegram.isSending || settings.telegramBotToken.isEmpty || settings.telegramChatID.isEmpty)

                if let status = telegram.lastSendStatus {
                    switch status {
                    case .success:
                        Label(Strings.telegramSent, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity.combined(with: .scale))
                    case .failure(let msg):
                        Label(msg, systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .animation(.spring(response: 0.3), value: telegram.lastSendStatus)
            .onChange(of: telegram.lastSendStatus) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    telegram.lastSendStatus = nil
                }
            }

            Text(Strings.tokenNote)
                .font(.caption)
                .foregroundStyle(.tertiary)
        } header: {
            Label(Strings.telegramSettings, systemImage: "paperplane.fill")
        }

        // Notifications
        Section {
            Toggle(isOn: $settings.enableNotifications) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.red)
                        .frame(width: 20)
                    Text(Strings.enableNotifications)
                }
            }
            .onChange(of: settings.enableNotifications) { _, newValue in
                if newValue {
                    NotificationManager.shared.requestPermissionIfNeeded()
                }
            }

            if settings.enableNotifications {
                Toggle(isOn: $settings.notifyOnErrors) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        Text(Strings.notifyOnErrors)
                    }
                }
                .padding(.leading, 32)

                Toggle(isOn: $settings.notifyOnMotion) {
                    HStack(spacing: 12) {
                        Image(systemName: "sensor.tag.radiowaves.forward.fill")
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        Text(Strings.notifyOnMotion)
                    }
                }
                .padding(.leading, 32)
            }
        } header: {
            Label(Strings.notifications, systemImage: "bell.fill")
        }

        // Motion Detection
        Section {
            Toggle(isOn: $settings.enableMotionDetection) {
                HStack(spacing: 12) {
                    Image(systemName: "sensor.tag.radiowaves.forward.fill")
                        .foregroundStyle(.green)
                        .frame(width: 20)
                    Text(Strings.enableMotionDetection)
                }
            }

            if settings.enableMotionDetection {
                Picker(Strings.motionSensitivity, selection: $settings.motionSensitivity) {
                    Text(Strings.low).tag(1)
                    Text(Strings.medium).tag(2)
                    Text(Strings.high).tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.leading, 32)

                Stepper("\(Strings.motionCooldown): \(settings.motionCooldownSeconds) \(Strings.seconds)", value: $settings.motionCooldownSeconds, in: 5...120, step: 5)
                    .padding(.leading, 32)

                Toggle(isOn: $settings.captureOnMotion) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 20)
                        Text(Strings.captureOnMotion)
                    }
                }
                .padding(.leading, 32)

                Toggle(isOn: $settings.telegramOnMotion) {
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 20)
                        Text(Strings.telegramOnMotion)
                    }
                }
                .padding(.leading, 32)
            }
        } header: {
            Label(Strings.motionDetection, systemImage: "sensor.tag.radiowaves.forward.fill")
        }
    }

    // MARK: - Camera Section

    @ViewBuilder
    private var cameraSection: some View {
        // Watermark
        Section {
            Toggle(isOn: $settings.enableWatermark) {
                HStack(spacing: 12) {
                    Image(systemName: "textformat.size")
                        .foregroundStyle(.purple)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Strings.enableWatermark)
                        Text(Strings.watermarkDesc)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Label(Strings.enableWatermark, systemImage: "textformat.size")
        }

        // Recording Settings
        Section {
            Toggle(isOn: $settings.enableAudioRecording) {
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text(Strings.enableAudioRecording)
                }
            }

            Stepper("\(Strings.segmentDuration): \(settings.segmentDurationMinutes > 0 ? "\(settings.segmentDurationMinutes) \(Strings.minutes)" : "--")",
                    value: $settings.segmentDurationMinutes, in: 0...120, step: 5)
            Text(Strings.segmentDurationDesc)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 32)
        } header: {
            Label(Strings.captureSettings, systemImage: "video.fill")
        }
    }

    // MARK: - Storage Section

    @ViewBuilder
    private var storageSection: some View {
        // Storage Management
        Section {
            storageRow(icon: "photo.stack", color: .blue, label: Strings.totalPhotos, value: "\(mediaLibrary.totalPhotoCount)")
            storageRow(icon: "film.stack", color: .purple, label: Strings.totalVideos, value: "\(mediaLibrary.totalVideoCount)")
            storageRow(icon: "internaldrive", color: .orange, label: Strings.storageUsage, value: ByteCountFormatter.string(fromByteCount: mediaLibrary.totalStorageBytes, countStyle: .file))

            Divider()

            Toggle(isOn: $settings.autoCleanEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.slash")
                        .foregroundStyle(.red)
                        .frame(width: 20)
                    Text(Strings.autoClean)
                }
            }

            if settings.autoCleanEnabled {
                Stepper(
                    "\(Strings.keepLastDays): \(settings.keepLastDays) \(Strings.days)",
                    value: $settings.keepLastDays,
                    in: 1...365
                )
                .padding(.leading, 32)
            }

            HStack(spacing: 12) {
                Button {
                    let count = mediaLibrary.cleanOldFiles(keepDays: settings.keepLastDays > 0 ? settings.keepLastDays : 30)
                    cleanResult = count
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        cleanResult = nil
                    }
                } label: {
                    Label(Strings.cleanNow, systemImage: "trash")
                }
                .disabled(settings.keepLastDays <= 0)

                if let result = cleanResult {
                    Text(String(format: Strings.cleanedCount, result))
                        .font(.caption)
                        .foregroundStyle(result > 0 ? .green : .secondary)
                        .transition(.opacity)
                }
            }
            .padding(.leading, 32)
            .animation(.spring(response: 0.3), value: cleanResult)
        } header: {
            Label(Strings.storageUsage, systemImage: "internaldrive")
        }

        // Custom Storage Path
        Section {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.customStoragePath)
                    Text(mediaLibrary.baseDirectory.path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            HStack(spacing: 8) {
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.begin { response in
                        guard response == .OK, let url = panel.url else { return }
                        settings.customStoragePath = url.path
                        mediaLibrary.ensureDirectoriesExist()
                        mediaLibrary.scanLibrary()
                    }
                } label: {
                    Label(Strings.chooseDirectory, systemImage: "folder.badge.gearshape")
                }

                if !settings.customStoragePath.isEmpty {
                    Button {
                        settings.customStoragePath = ""
                        mediaLibrary.ensureDirectoriesExist()
                        mediaLibrary.scanLibrary()
                    } label: {
                        Label(Strings.resetToDefault, systemImage: "arrow.counterclockwise")
                    }
                }
            }
        } header: {
            Label(Strings.customStoragePath, systemImage: "folder")
        }

        // Storage Provider
        Section {
            Picker(Strings.storageProviders, selection: $settings.activeStorageProviderType) {
                Text(Strings.none).tag("none")
                Text(Strings.localFolder).tag("localFolder")
                Text(Strings.mountedFolder).tag("mountedFolder")
                Text(Strings.googleDrive).tag("googleDrive")
                Text("\(Strings.webdav) (Planned)").tag("webdav")
            }
            .onChange(of: settings.activeStorageProviderType) { _, _ in
                StorageManager.shared.configure()
                storageTestResult = nil
            }

            if settings.activeStorageProviderType == "localFolder" {
                localFolderConfig
            }

            if settings.activeStorageProviderType == "mountedFolder" {
                mountedFolderConfig
            }

            if settings.activeStorageProviderType == "googleDrive" {
                googleDriveConfig
            }

            if settings.activeStorageProviderType == "webdav" {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.orange)
                        .frame(width: 20)
                    Text("WebDAV provider is planned and not fully implemented yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label(Strings.storageProviders, systemImage: "externaldrive")
        }

        // Upload Queue
        Section {
            Toggle(isOn: $settings.autoUploadPhotos) {
                HStack(spacing: 12) {
                    Image(systemName: "photo")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text(Strings.autoUploadPhotos)
                }
            }

            Toggle(isOn: $settings.autoUploadVideos) {
                HStack(spacing: 12) {
                    Image(systemName: "video")
                        .foregroundStyle(.purple)
                        .frame(width: 20)
                    Text(Strings.autoUploadVideos)
                }
            }

            Stepper("\(Strings.maxConcurrentUploads): \(settings.uploadMaxConcurrent)", value: $settings.uploadMaxConcurrent, in: 1...5)
                .padding(.leading, 32)

            Stepper("Max Retries: \(settings.uploadMaxRetries)", value: $settings.uploadMaxRetries, in: 0...10)
                .padding(.leading, 32)
        } header: {
            Label(Strings.uploadQueue, systemImage: "arrow.up.circle")
        }
    }

    // MARK: - Web & Remote Section

    @ViewBuilder
    private var webRemoteSection: some View {
        // Web Server
        Section {
            Toggle(isOn: $settings.webServerEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Strings.webServer)
                        Text("\(Strings.webServerAddress): \(settings.webServerBindAddress):\(settings.webServerPort)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .onChange(of: settings.webServerEnabled) { _, newValue in
                if newValue {
                    WebServerManager.shared.start()
                } else {
                    WebServerManager.shared.stop()
                }
            }

            if settings.webServerEnabled {
                Stepper("\(Strings.webServerPort): \(settings.webServerPort)", value: $settings.webServerPort, in: 1024...65535, step: 1)
                    .padding(.leading, 32)
                    .onChange(of: settings.webServerPort) { _, _ in
                        WebServerManager.shared.restart()
                    }

                HStack(spacing: 12) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(WebServerManager.shared.isRunning ? .green : .red)
                    Text(WebServerManager.shared.isRunning ? Strings.webServerRunning : Strings.webServerStopped)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 32)

                // Web login credentials
                VStack(alignment: .leading, spacing: 8) {
                    Text("Web Login / 网页登录")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Username / 用户名:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("admin", text: $webUsername)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 160)
                        Button("Save / 保存") {
                            let old = WebAuthManager.shared.currentAdminUsername()
                            let new = webUsername.trimmingCharacters(in: .whitespaces)
                            guard !new.isEmpty else { return }
                            if WebAuthManager.shared.changeAdminUsername(from: old, to: new) {
                                webCredentialMessage = "Username saved / 用户名已保存"
                                webCredentialIsError = false
                            } else {
                                webCredentialMessage = "Invalid or duplicate username / 用户名无效或已存在"
                                webCredentialIsError = true
                                webUsername = old
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { webCredentialMessage = nil }
                        }
                        .font(.caption)
                    }

                    HStack {
                        if showWebPassword {
                            Text("Password / 密码: \(webPassword)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .textSelection(.enabled)
                        } else {
                            Text("Password / 密码: ••••••••")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(showWebPassword ? "Hide / 隐藏" : "Show / 显示") {
                            if webPassword.isEmpty {
                                webPassword = KeychainService.shared.webAuthSecret
                            }
                            showWebPassword.toggle()
                        }
                        .font(.caption)
                    }

                    HStack {
                        Button("Reset Password / 重置密码") {
                            let newPwd = String((0..<12).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
                            if WebAuthManager.shared.changeAdminPassword(newPassword: newPwd) {
                                webPassword = newPwd
                                showWebPassword = true
                                webCredentialMessage = "Password reset / 密码已重置"
                                webCredentialIsError = false
                            } else {
                                webCredentialMessage = "Failed to reset password / 密码重置失败"
                                webCredentialIsError = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { webCredentialMessage = nil }
                        }
                        .font(.caption)
                    }
                }
                .padding(.leading, 32)
                .onAppear {
                    webPassword = KeychainService.shared.webAuthSecret
                    webUsername = WebAuthManager.shared.currentAdminUsername()
                }

                if let msg = webCredentialMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(webCredentialIsError ? .red : .green)
                        .padding(.leading, 32)
                        .transition(.opacity)
                }
            }
        } header: {
            Label(Strings.webServer, systemImage: "globe")
        }

        // Cloudflare Tunnel
        Section {
            HStack(spacing: 12) {
                Image(systemName: cloudflaredDetected ? "checkmark.circle.fill" : "questionmark.circle")
                    .foregroundStyle(cloudflaredDetected ? .green : .orange)
                    .frame(width: 20)
                Text(cloudflaredDetected ? Strings.cloudflaredDetected : Strings.cloudflaredNotDetected)
                    .font(.caption)
                    .foregroundStyle(cloudflaredDetected ? .green : .orange)
                if cloudflaredDetected && !cloudflaredPath.isEmpty {
                    Text("(\(cloudflaredPath))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .onAppear {
                let fm = FileManager.default
                for path in ["/opt/homebrew/bin/cloudflared", "/usr/local/bin/cloudflared"] {
                    if fm.fileExists(atPath: path) {
                        cloudflaredDetected = true
                        cloudflaredPath = path
                        return
                    }
                }
                cloudflaredDetected = false
            }

            HStack(spacing: 12) {
                Image(systemName: "network.badge.shield.half.filled")
                    .foregroundStyle(.orange)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.cloudflareTunnel)
                    Text(Strings.remoteAccessDesc)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "lock.rectangle.stack")
                    .foregroundStyle(.green)
                    .frame(width: 20)
                Text(Strings.cloudflareDoubleProtection)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DisclosureGroup(Strings.cloudflareSetupWizard) {
                VStack(alignment: .leading, spacing: 12) {
                    cfWizardStep(step: 1, title: Strings.cloudflareStep1, command: "brew install cloudflared", description: "Install the Cloudflare Tunnel client")
                    cfWizardStep(step: 2, title: Strings.cloudflareStep2, command: "cloudflared tunnel login", description: "Authenticate with your Cloudflare account")
                    cfWizardStep(step: 3, title: Strings.cloudflareStep3, command: "cloudflared tunnel create mac-monitor", description: "Create a named tunnel")
                    cfWizardStep(step: 4, title: Strings.cloudflareStep4, command: "cloudflared tunnel route dns mac-monitor monitor.yourdomain.com", description: "Point your domain to the tunnel")
                    let port = settings.webServerPort
                    cfWizardStep(step: 5, title: Strings.cloudflareStep5, command: "cloudflared tunnel run --url http://127.0.0.1:\(port) mac-monitor", description: "Start tunneling traffic to local web server")

                    Text(Strings.cloudflareDoubleProtection)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
        } header: {
            Label(Strings.remoteAccess, systemImage: "network.badge.shield.half.filled")
        }
    }

    // MARK: - Automation Section

    @ViewBuilder
    private var automationSection: some View {
        Section {
            ForEach(automation.tasks) { task in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.name.isEmpty ? task.type.displayName : task.name)
                            .font(.body)
                        HStack(spacing: 8) {
                            Text(task.actionType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(task.type.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if task.uploadToCloud {
                                Image(systemName: "icloud.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { task.isEnabled },
                        set: { newValue in
                            if let idx = automation.tasks.firstIndex(where: { $0.id == task.id }) {
                                automation.tasks[idx].isEnabled = newValue
                                automation.saveAllTasks()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingTask = task
                    showTaskSheet = true
                }
            }
            .onDelete { indexSet in
                automation.tasks.remove(atOffsets: indexSet)
                automation.saveAllTasks()
            }

            Button {
                editingTask = nil
                showTaskSheet = true
            } label: {
                Label("Create Task", systemImage: "plus.circle.fill")
            }
        } header: {
            Label(Strings.automation, systemImage: "list.bullet")
        }

        Section {
            Stepper("\(Strings.recoveryWindow): \(settings.recoveryWindowMinutes) \(Strings.minutes)", value: $settings.recoveryWindowMinutes, in: 0...120, step: 5)
        } header: {
            Label(Strings.missedTaskRecovery, systemImage: "arrow.clockwise")
        }

        Section {
            Toggle(isOn: $settings.eventRecordingEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "film")
                        .foregroundStyle(.orange)
                        .frame(width: 20)
                    Text(Strings.enableEventRecording)
                }
            }

            if settings.eventRecordingEnabled {
                Stepper("\(Strings.eventClipDuration): \(settings.eventClipDurationSeconds)s", value: $settings.eventClipDurationSeconds, in: 3...60, step: 3)
                    .padding(.leading, 32)

                Toggle(isOn: $settings.autoUploadEventClips) {
                    Text(Strings.uploadEventClips)
                }
                .padding(.leading, 32)
            }
        } header: {
            Label(Strings.eventRecording, systemImage: "film")
        }

        Section {
            Toggle(isOn: $settings.dailyReportEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text(Strings.dailyReport)
                }
            }

            if settings.dailyReportEnabled {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    DatePicker(Strings.reportTime, selection: Binding(
                        get: {
                            var components = DateComponents()
                            components.hour = settings.dailyReportHour
                            components.minute = settings.dailyReportMinute
                            return Calendar.current.date(from: components) ?? Date()
                        },
                        set: { date in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                            settings.dailyReportHour = components.hour ?? 23
                            settings.dailyReportMinute = components.minute ?? 55
                        }
                    ), displayedComponents: .hourAndMinute)
                }
                .padding(.leading, 32)
            }
        } header: {
            Label(Strings.dailyReport, systemImage: "doc.text")
        }

        Section {
            Toggle(isOn: $settings.timelapseEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "timelapse")
                        .foregroundStyle(.green)
                        .frame(width: 20)
                    Text(Strings.enableTimelapse)
                }
            }

            if settings.timelapseEnabled {
                Stepper("\(Strings.captureInterval): \(settings.timelapseIntervalSeconds)s", value: $settings.timelapseIntervalSeconds, in: 5...3600, step: 5)
                    .padding(.leading, 32)

                Stepper("\(Strings.outputFPS): \(settings.timelapseFPS)", value: $settings.timelapseFPS, in: 1...60, step: 5)
                    .padding(.leading, 32)

                Toggle(isOn: $settings.autoUploadTimelapse) {
                    Text(Strings.autoUploadTimelapse)
                }
                .padding(.leading, 32)
            }
        } header: {
            Label(Strings.timelapse, systemImage: "timelapse")
        }
    }

    // MARK: - Retention Section

    @ViewBuilder
    private var retentionSection: some View {
        Section {
            Toggle(isOn: $settings.retentionDeleteAfterUpload) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.slash")
                        .foregroundStyle(.red)
                        .frame(width: 20)
                    Text(Strings.deleteLocalAfterUpload)
                }
            }

            if settings.retentionDeleteAfterUpload {
                Stepper("\(Strings.gracePeriodHours): \(settings.retentionGracePeriodHours)h", value: $settings.retentionGracePeriodHours, in: 1...168)
                    .padding(.leading, 32)

                Toggle(isOn: $settings.retentionProtectFavorites) {
                    Text(Strings.protectFavorites)
                }
                .padding(.leading, 32)

                HStack(spacing: 8) {
                    Button(Strings.runDryRun) {
                        dryRunResult = RetentionManager.shared.dryRun()
                    }
                    .buttonStyle(.bordered)

                    Button("Run Cleanup Now / 立即执行清理") {
                        let count = RetentionManager.shared.runCleanup()
                        cleanResult = count
                    }
                }
                .padding(.leading, 32)

                if let dry = dryRunResult {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Strings.dryRunPreview)
                            .font(.caption)
                            .fontWeight(.medium)
                        if let reason = dry.reason {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(String(format: Strings.willDeleteCount, dry.wouldDelete))
                                .font(.caption)
                                .foregroundStyle(dry.wouldDelete > 0 ? .orange : .secondary)
                            if dry.skipped > 0 {
                                Text("\(Strings.skipped): \(dry.skipped)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.leading, 32)
                }

                if let result = cleanResult {
                    Text("Cleaned \(result) local original(s)")
                        .font(.caption)
                        .foregroundStyle(result > 0 ? .orange : .secondary)
                        .padding(.leading, 32)
                }
            }
        } header: {
            Label(Strings.retentionPolicy, systemImage: "trash.slash")
        }
    }

    // MARK: - Advanced Section

    @ViewBuilder
    private var advancedSection: some View {
        // Privacy & Security
        Section {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.green)
                    .frame(width: 20)
                Text(Strings.tokenInKeychain)
                    .font(.callout)
            }

            Button {
                settings.telegramBotToken = ""
            } label: {
                Label(Strings.clearToken, systemImage: "trash")
            }
            .disabled(settings.telegramBotToken.isEmpty)
        } header: {
            Label(Strings.privacySecurity, systemImage: "lock.shield.fill")
        }

        // Language
        Section {
            Picker(Strings.language, selection: Binding(
                get: { lang.currentLanguage },
                set: { lang.setLanguage($0) }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Label(Strings.language, systemImage: "globe")
        }

        // Health Monitor
        Section {
            Toggle(isOn: $settings.enableHealthMonitor) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .frame(width: 20)
                    Text(Strings.enableHealthMonitor)
                }
            }
            .onChange(of: settings.enableHealthMonitor) { _, newValue in
                if newValue {
                    HealthMonitor.shared.startMonitoring()
                } else {
                    HealthMonitor.shared.stopMonitoring()
                }
            }

            if settings.enableHealthMonitor {
                Toggle(isOn: $settings.notifyCameraDisconnect) {
                    HStack(spacing: 12) {
                        Image(systemName: "video.slash.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        Text(Strings.notifyCameraDisconnect)
                    }
                }
                .padding(.leading, 32)

                Toggle(isOn: $settings.notifyLowDisk) {
                    HStack(spacing: 12) {
                        Image(systemName: "internaldrive.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        Text(Strings.notifyLowDisk)
                    }
                }
                .padding(.leading, 32)

                if settings.notifyLowDisk {
                    Stepper("\(Strings.lowDiskThreshold): \(settings.lowDiskThresholdMB) MB", value: $settings.lowDiskThresholdMB, in: 100...5000, step: 100)
                        .padding(.leading, 52)
                }

                Toggle(isOn: $settings.notifyTelegramFailure) {
                    HStack(spacing: 12) {
                        Image(systemName: "paperplane.slash.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        Text(Strings.notifyTelegramFailure)
                    }
                }
                .padding(.leading, 32)
            }
        } header: {
            Label(Strings.healthMonitor, systemImage: "heart.fill")
        }

        // About
        Section {
            aboutRow("System", ProcessInfo.processInfo.operatingSystemVersionString)
            aboutRow("Version", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.4.2")
            aboutRow("Bundle ID", "com.kairkiss.MacMonitor")
        } header: {
            Label(Strings.about, systemImage: "info.circle")
        }
    }

    // MARK: - Storage Provider Configs

    @ViewBuilder
    private var localFolderConfig: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundStyle(.blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.localFolder)
                Text(settings.localFolderPath.isEmpty ? "Not set" : settings.localFolderPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }

        HStack(spacing: 8) {
            Button {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    settings.localFolderPath = url.path
                    StorageManager.shared.configure()
                }
            } label: {
                Label(Strings.chooseDirectory, systemImage: "folder.badge.gearshape")
            }

            if !settings.localFolderPath.isEmpty {
                Button {
                    settings.localFolderPath = ""
                    StorageManager.shared.configure()
                } label: {
                    Label(Strings.resetToDefault, systemImage: "arrow.counterclockwise")
                }
            }

            Button {
                Task {
                    storageTestResult = await StorageManager.shared.testConnection()
                }
            } label: {
                Label(Strings.testConnection, systemImage: "network")
            }
            .disabled(settings.localFolderPath.isEmpty)
        }

        if let result = storageTestResult {
            Label(result ? "Connected" : "Failed", systemImage: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(result ? .green : .red)
        }
    }

    @ViewBuilder
    private var mountedFolderConfig: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive")
                .foregroundStyle(.purple)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.mountedFolder)
                Text(settings.mountedFolderPath.isEmpty ? "Not set" : settings.mountedFolderPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }

        HStack(spacing: 8) {
            Button {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    settings.mountedFolderPath = url.path
                    StorageManager.shared.configure()
                }
            } label: {
                Label(Strings.chooseDirectory, systemImage: "folder.badge.gearshape")
            }

            if !settings.mountedFolderPath.isEmpty {
                Button {
                    settings.mountedFolderPath = ""
                    StorageManager.shared.configure()
                } label: {
                    Label(Strings.resetToDefault, systemImage: "arrow.counterclockwise")
                }
            }

            Button {
                Task {
                    storageTestResult = await StorageManager.shared.testConnection()
                }
            } label: {
                Label(Strings.testConnection, systemImage: "network")
            }
            .disabled(settings.mountedFolderPath.isEmpty)
        }

        if let result = storageTestResult {
            Label(result ? "Connected" : "Failed", systemImage: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(result ? .green : .red)
        }
    }

    @ViewBuilder
    private var googleDriveConfig: some View {
        let auth = GoogleDriveAuthManager.shared
        Color.clear.onAppear {
            if gdClientSecret.isEmpty {
                gdClientSecret = KeychainService.shared.googleDriveClientSecret
            }
        }
        HStack(spacing: 12) {
            Image(systemName: "cloud")
                .foregroundStyle(.orange)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.googleDriveAccount)
                if auth.isAuthenticated {
                    Text(auth.userEmail)
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if auth.needsReconnect {
                    Text(Strings.googleDriveNeedsReconnect)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text(Strings.googleDriveNotAuthenticated)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }

        if !auth.isAuthenticated || auth.needsReconnect {
            HStack(spacing: 12) {
                Image(systemName: "key")
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                TextField(Strings.googleDriveClientID, text: $settings.googleDriveClientID)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                SecureField(Strings.googleDriveClientSecret, text: $gdClientSecret)
                    .textFieldStyle(.roundedBorder)
            }

            Text(Strings.googleDriveSetupDesc)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 32)

            Text(Strings.googleDriveRedirectNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 32)

            Button {
                Task {
                    guard !settings.googleDriveClientID.isEmpty, !gdClientSecret.isEmpty else {
                        gdAuthMessage = Strings.googleDriveCredentialsRequired
                        gdAuthIsError = true
                        return
                    }
                    do {
                        settings.googleDriveClientSecret = gdClientSecret
                        try await auth.authenticate(
                            clientID: settings.googleDriveClientID,
                            clientSecret: gdClientSecret
                        )
                        gdAuthMessage = Strings.googleDriveAuthenticated
                        gdAuthIsError = false
                        StorageManager.shared.configure()
                    } catch {
                        gdAuthMessage = error.localizedDescription
                        gdAuthIsError = true
                    }
                }
            } label: {
                if auth.isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                    Text(Strings.testing)
                } else {
                    Label(auth.needsReconnect ? Strings.googleDriveReconnect : Strings.googleDriveSignIn, systemImage: "person.crop.circle.badge.checkmark")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.leading, 32)
            .disabled(auth.isAuthenticating)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .frame(width: 20)
                Text(Strings.googleDriveAuthenticated)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                TextField(Strings.googleDriveRootFolderName, text: $settings.googleDriveRootFolderName)
                    .textFieldStyle(.roundedBorder)
            }
            Text(Strings.googleDriveRootFolderNameDesc)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 32)

            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.googleDriveFolderStructure)
                    Text(Strings.googleDriveFolderStructureDesc)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield")
                    .foregroundStyle(.green)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Strings.googleDriveNoOverwrite)
                    Text(Strings.googleDriveNoOverwriteDesc)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                Text(Strings.googleDriveResumable)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    Task {
                        storageTestResult = await StorageManager.shared.testConnection()
                        storageDiagnostics = await StorageManager.shared.testConnectionDetailed()
                    }
                } label: {
                    Label(Strings.connectionTest, systemImage: "network")
                }

                Button(role: .destructive) {
                    auth.signOut()
                    StorageManager.shared.configure()
                } label: {
                    Label(Strings.googleDriveSignOut, systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
            .padding(.leading, 32)
        }

        if let result = storageTestResult {
            Label(result ? Strings.providerConnected : Strings.providerDisconnected, systemImage: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(result ? .green : .red)
                .padding(.leading, 32)
        }

        if let diag = storageDiagnostics {
            VStack(alignment: .leading, spacing: 4) {
                if let email = diag.authenticatedEmail {
                    storageRow(icon: "person.circle", color: .blue, label: Strings.googleDriveAccount, value: email)
                }
                if let used = diag.quotaUsedGB, let total = diag.quotaTotalGB, total > 0 {
                    storageRow(icon: "internaldrive", color: .purple, label: Strings.quotaInfo, value: String(format: "%.1f / %.1f GB", used, total))
                }
                if let errClass = diag.lastTestErrorClass, errClass != .unknown {
                    storageRow(icon: "exclamationmark.triangle", color: .orange, label: Strings.errorClass, value: errClass.localizedDescription)
                }
                if let error = diag.lastTestError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                HStack(spacing: 4) {
                    Text(Strings.lastSuccessfulUpload + ":")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(diag.recentUploadCount) verified, \(diag.recentFailureCount) failed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 32)
        }

        if let msg = gdAuthMessage {
            Text(msg)
                .font(.caption)
                .foregroundStyle(gdAuthIsError ? .red : .green)
                .padding(.leading, 32)
        }
    }

    private func storageRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .font(.callout.monospaced())
        }
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func cfWizardStep(step: Int, title: String, command: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("\(step)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.orange))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
            HStack(spacing: 8) {
                Text(command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.blue)
                    .textSelection(.enabled)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    cfCopiedMessage = Strings.copiedToClipboard
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        cfCopiedMessage = nil
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(6)
            .padding(.leading, 28)
        }
    }
}
