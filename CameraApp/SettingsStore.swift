import Foundation

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var telegramBotToken: String {
        didSet { KeychainService.shared.telegramBotToken = telegramBotToken }
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
    @Published var recoveryWindowMinutes: Int {
        didSet { UserDefaults.standard.set(recoveryWindowMinutes, forKey: "recoveryWindowMinutes") }
    }
    @Published var enableMotionDetection: Bool {
        didSet { UserDefaults.standard.set(enableMotionDetection, forKey: "enableMotionDetection") }
    }
    @Published var motionSensitivity: Int {
        didSet { UserDefaults.standard.set(motionSensitivity, forKey: "motionSensitivity") }
    }
    @Published var motionCooldownSeconds: Int {
        didSet { UserDefaults.standard.set(motionCooldownSeconds, forKey: "motionCooldownSeconds") }
    }
    @Published var captureOnMotion: Bool {
        didSet { UserDefaults.standard.set(captureOnMotion, forKey: "captureOnMotion") }
    }
    @Published var telegramOnMotion: Bool {
        didSet { UserDefaults.standard.set(telegramOnMotion, forKey: "telegramOnMotion") }
    }
    @Published var enableHealthMonitor: Bool {
        didSet { UserDefaults.standard.set(enableHealthMonitor, forKey: "enableHealthMonitor") }
    }
    @Published var notifyCameraDisconnect: Bool {
        didSet { UserDefaults.standard.set(notifyCameraDisconnect, forKey: "notifyCameraDisconnect") }
    }
    @Published var notifyLowDisk: Bool {
        didSet { UserDefaults.standard.set(notifyLowDisk, forKey: "notifyLowDisk") }
    }
    @Published var notifyTelegramFailure: Bool {
        didSet { UserDefaults.standard.set(notifyTelegramFailure, forKey: "notifyTelegramFailure") }
    }
    @Published var lowDiskThresholdMB: Int {
        didSet { UserDefaults.standard.set(lowDiskThresholdMB, forKey: "lowDiskThresholdMB") }
    }
    @Published var enableNotifications: Bool {
        didSet { UserDefaults.standard.set(enableNotifications, forKey: "enableNotifications") }
    }
    @Published var notifyOnErrors: Bool {
        didSet { UserDefaults.standard.set(notifyOnErrors, forKey: "notifyOnErrors") }
    }
    @Published var notifyOnMotion: Bool {
        didSet { UserDefaults.standard.set(notifyOnMotion, forKey: "notifyOnMotion") }
    }
    @Published var segmentDurationMinutes: Int {
        didSet { UserDefaults.standard.set(segmentDurationMinutes, forKey: "segmentDurationMinutes") }
    }
    @Published var enableAudioRecording: Bool {
        didSet { UserDefaults.standard.set(enableAudioRecording, forKey: "enableAudioRecording") }
    }
    @Published var slideshowIntervalSeconds: Int {
        didSet { UserDefaults.standard.set(slideshowIntervalSeconds, forKey: "slideshowIntervalSeconds") }
    }

    private init() {
        telegramBotToken = KeychainService.shared.telegramBotToken
        telegramChatID = UserDefaults.standard.string(forKey: "telegramChatID") ?? ""
        enableWatermark = UserDefaults.standard.bool(forKey: "enableWatermark")
        autoCleanEnabled = UserDefaults.standard.bool(forKey: "autoCleanEnabled")
        keepLastDays = UserDefaults.standard.integer(forKey: "keepLastDays")
        selectedCameraID = UserDefaults.standard.string(forKey: "selectedCameraID") ?? ""
        customStoragePath = UserDefaults.standard.string(forKey: "customStoragePath") ?? ""
        recoveryWindowMinutes = UserDefaults.standard.object(forKey: "recoveryWindowMinutes") as? Int ?? 30
        enableMotionDetection = UserDefaults.standard.bool(forKey: "enableMotionDetection")
        motionSensitivity = UserDefaults.standard.object(forKey: "motionSensitivity") as? Int ?? 2  // 1=low, 2=med, 3=high
        motionCooldownSeconds = UserDefaults.standard.object(forKey: "motionCooldownSeconds") as? Int ?? 10
        captureOnMotion = UserDefaults.standard.bool(forKey: "captureOnMotion")
        telegramOnMotion = UserDefaults.standard.bool(forKey: "telegramOnMotion")
        enableHealthMonitor = UserDefaults.standard.bool(forKey: "enableHealthMonitor")
        notifyCameraDisconnect = UserDefaults.standard.bool(forKey: "notifyCameraDisconnect")
        notifyLowDisk = UserDefaults.standard.bool(forKey: "notifyLowDisk")
        notifyTelegramFailure = UserDefaults.standard.bool(forKey: "notifyTelegramFailure")
        lowDiskThresholdMB = UserDefaults.standard.object(forKey: "lowDiskThresholdMB") as? Int ?? 500
        enableNotifications = UserDefaults.standard.bool(forKey: "enableNotifications")
        notifyOnErrors = UserDefaults.standard.bool(forKey: "notifyOnErrors")
        notifyOnMotion = UserDefaults.standard.bool(forKey: "notifyOnMotion")
        segmentDurationMinutes = UserDefaults.standard.object(forKey: "segmentDurationMinutes") as? Int ?? 0
        enableAudioRecording = UserDefaults.standard.bool(forKey: "enableAudioRecording")
        slideshowIntervalSeconds = UserDefaults.standard.object(forKey: "slideshowIntervalSeconds") as? Int ?? 5
    }
}
