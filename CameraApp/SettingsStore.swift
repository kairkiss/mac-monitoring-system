import Foundation

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var telegramBotToken: String {
        didSet { UserDefaults.standard.set(telegramBotToken, forKey: "telegramBotToken") }
    }
    @Published var telegramChatID: String {
        didSet { UserDefaults.standard.set(telegramChatID, forKey: "telegramChatID") }
    }
    @Published var enableWatermark: Bool {
        didSet { UserDefaults.standard.set(enableWatermark, forKey: "enableWatermark") }
    }
    @Published var autoCleanEnabled: Bool {
        didSet { UserDefaults.standard.set(autoCleanEnabled, forKey: "autoCleanEnabled") }
    }
    @Published var keepLastDays: Int {
        didSet { UserDefaults.standard.set(keepLastDays, forKey: "keepLastDays") }
    }
    @Published var selectedCameraID: String {
        didSet { UserDefaults.standard.set(selectedCameraID, forKey: "selectedCameraID") }
    }
    @Published var customStoragePath: String {
        didSet { UserDefaults.standard.set(customStoragePath, forKey: "customStoragePath") }
    }

    private init() {
        telegramBotToken = UserDefaults.standard.string(forKey: "telegramBotToken") ?? ""
        telegramChatID = UserDefaults.standard.string(forKey: "telegramChatID") ?? ""
        enableWatermark = UserDefaults.standard.bool(forKey: "enableWatermark")
        autoCleanEnabled = UserDefaults.standard.bool(forKey: "autoCleanEnabled")
        keepLastDays = UserDefaults.standard.integer(forKey: "keepLastDays")
        selectedCameraID = UserDefaults.standard.string(forKey: "selectedCameraID") ?? ""
        customStoragePath = UserDefaults.standard.string(forKey: "customStoragePath") ?? ""
    }
}
