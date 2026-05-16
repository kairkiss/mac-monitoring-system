import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var telegram: TelegramService
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var mediaLibrary: MediaLibraryManager
    @State private var cleanResult: Int?

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
                aboutRow("Version", "1.2.1")
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
