import Foundation

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var telegramBotToken: String {
        didSet { UserDefaults.standard.set(telegramBotToken, forKey: "telegramBotToken") }
    }
    @Published var telegramChatID: String {
        didSet { UserDefaults.standard.set(telegramChatID, forKey: "telegramChatID") }
    }

    private init() {
        telegramBotToken = UserDefaults.standard.string(forKey: "telegramBotToken") ?? ""
        telegramChatID = UserDefaults.standard.string(forKey: "telegramChatID") ?? ""
    }
}
