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
                aboutRow("Version", "1.1.1")
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
