import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var telegram: TelegramService
    @EnvironmentObject var lang: LanguageManager

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
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(Strings.telegramSent)
                                .font(.caption)
                                .foregroundStyle(.green)
                        case .failure(let msg):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        }
                    }
                }

                Text(Strings.tokenNote)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } header: {
                Label(Strings.telegramSettings, systemImage: "paperplane.fill")
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
                HStack {
                    Text(Strings.storagePath)
                    Spacer()
                    Text(MediaLibraryManager.shared.baseDirectory.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                HStack {
                    Text("System")
                    Spacer()
                    Text(ProcessInfo.processInfo.operatingSystemVersionString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(Strings.about, systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Strings.settingsTitle)
    }
}
