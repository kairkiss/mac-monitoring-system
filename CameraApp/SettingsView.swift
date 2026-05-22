import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var telegram: TelegramService
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var mediaLibrary: MediaLibraryManager
    @State private var cleanResult: Int?
    @State private var storageTestResult: Bool?
    @State private var webPassword: String = ""
    @State private var showWebPassword: Bool = false

    var body: some View {
        Form {
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.enableAudioRecording)
                        }
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
                    Text("\(Strings.googleDrive) (Planned)").tag("googleDrive")
                    Text("\(Strings.webdav) (Planned)").tag("webdav")
                }
                .onChange(of: settings.activeStorageProviderType) { _, _ in
                    StorageManager.shared.configure()
                    storageTestResult = nil
                }

                if settings.activeStorageProviderType == "localFolder" {
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

                if settings.activeStorageProviderType == "mountedFolder" {
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

                if settings.activeStorageProviderType == "googleDrive" {
                    HStack(spacing: 12) {
                        Image(systemName: "cloud")
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        Text("Google Drive provider is planned and not fully implemented in v2.0.2.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if settings.activeStorageProviderType == "webdav" {
                    HStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        Text("WebDAV provider is planned and not fully implemented in v2.0.2.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label(Strings.storageProviders, systemImage: "externaldrive")
            }

            // Motion Detection
            Section {
                Toggle(isOn: $settings.enableMotionDetection) {
                    HStack(spacing: 12) {
                        Image(systemName: "sensor.tag.radiowaves.forward.fill")
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.enableMotionDetection)
                        }
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

            // Automation Recovery
            Section {
                Stepper("\(Strings.recoveryWindow): \(settings.recoveryWindowMinutes) \(Strings.minutes)", value: $settings.recoveryWindowMinutes, in: 0...120, step: 5)
            } header: {
                Label(Strings.missedTaskRecovery, systemImage: "arrow.clockwise")
            }

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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Web Login / 网页登录")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Reset Password / 重置密码") {
                                let newPwd = String((0..<12).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
                                KeychainService.shared.webAuthSecret = newPwd
                                WebAuthManager.shared.changePassword(username: "admin", newPassword: newPwd)
                                webPassword = newPwd
                                showWebPassword = true
                            }
                            .font(.caption)
                        }
                        HStack {
                            Text("Username: admin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        HStack {
                            if showWebPassword {
                                Text("Password: \(webPassword)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .textSelection(.enabled)
                            } else {
                                Text("Password: ••••••••")
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
                    }
                    .padding(.leading, 32)
                    .onAppear {
                        webPassword = KeychainService.shared.webAuthSecret
                    }
                }
            } header: {
                Label(Strings.webServer, systemImage: "globe")
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

            // Retention Policy
            Section {
                Toggle(isOn: $settings.retentionDeleteAfterUpload) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.slash")
                            .foregroundStyle(.red)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.deleteLocalAfterUpload)
                        }
                    }
                }

                if settings.retentionDeleteAfterUpload {
                    Stepper("\(Strings.gracePeriodHours): \(settings.retentionGracePeriodHours)h", value: $settings.retentionGracePeriodHours, in: 1...168)
                        .padding(.leading, 32)

                    Toggle(isOn: $settings.retentionProtectFavorites) {
                        Text(Strings.protectFavorites)
                    }
                    .padding(.leading, 32)

                    Button("Run Cleanup Now / 立即执行清理") {
                        let count = RetentionManager.shared.runCleanup()
                        cleanResult = count
                    }
                    .padding(.leading, 32)

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

            // Event Recording
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

            // Daily Report
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

            // Timelapse
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

            // About
            Section {
                aboutRow("System", ProcessInfo.processInfo.operatingSystemVersionString)
                aboutRow("Version", "2.1.1")
                aboutRow("Bundle ID", "com.kairkiss.MacMonitor")
            } header: {
                Label(Strings.about, systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Strings.settingsTitle)
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
}
