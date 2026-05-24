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

    // MARK: - Web Server
    @Published var webServerEnabled: Bool {
        didSet { UserDefaults.standard.set(webServerEnabled, forKey: "webServerEnabled") }
    }
    @Published var webServerPort: Int {
        didSet { UserDefaults.standard.set(webServerPort, forKey: "webServerPort") }
    }
    @Published var webServerBindAddress: String {
        didSet { UserDefaults.standard.set(webServerBindAddress, forKey: "webServerBindAddress") }
    }

    // MARK: - Storage Provider
    @Published var activeStorageProviderType: String {
        didSet { UserDefaults.standard.set(activeStorageProviderType, forKey: "activeStorageProviderType") }
    }
    @Published var localFolderPath: String {
        didSet { UserDefaults.standard.set(localFolderPath, forKey: "localFolderPath") }
    }
    @Published var mountedFolderPath: String {
        didSet { UserDefaults.standard.set(mountedFolderPath, forKey: "mountedFolderPath") }
    }
    @Published var googleDriveFolderID: String {
        didSet { UserDefaults.standard.set(googleDriveFolderID, forKey: "googleDriveFolderID") }
    }
    @Published var googleDriveClientID: String {
        didSet { UserDefaults.standard.set(googleDriveClientID, forKey: "googleDriveClientID") }
    }
    var googleDriveClientSecret: String {
        get { KeychainService.shared.googleDriveClientSecret }
        set { KeychainService.shared.googleDriveClientSecret = newValue }
    }
    @Published var googleDriveRootFolderName: String {
        didSet { UserDefaults.standard.set(googleDriveRootFolderName, forKey: "googleDriveRootFolderName") }
    }
    @Published var webdavURL: String {
        didSet { UserDefaults.standard.set(webdavURL, forKey: "webdavURL") }
    }
    @Published var webdavUsername: String {
        didSet { UserDefaults.standard.set(webdavUsername, forKey: "webdavUsername") }
    }
    @Published var webdavBasePath: String {
        didSet { UserDefaults.standard.set(webdavBasePath, forKey: "webdavBasePath") }
    }
    @Published var allowInsecureWebDAV: Bool {
        didSet { UserDefaults.standard.set(allowInsecureWebDAV, forKey: "allowInsecureWebDAV") }
    }

    // MARK: - Upload
    @Published var autoUploadPhotos: Bool {
        didSet { UserDefaults.standard.set(autoUploadPhotos, forKey: "autoUploadPhotos") }
    }
    @Published var autoUploadVideos: Bool {
        didSet { UserDefaults.standard.set(autoUploadVideos, forKey: "autoUploadVideos") }
    }
    @Published var uploadMaxConcurrent: Int {
        didSet { UserDefaults.standard.set(uploadMaxConcurrent, forKey: "uploadMaxConcurrent") }
    }
    @Published var uploadMaxRetries: Int {
        didSet { UserDefaults.standard.set(uploadMaxRetries, forKey: "uploadMaxRetries") }
    }
    @Published var uploadBandwidthLimitKBps: Int {
        didSet { UserDefaults.standard.set(uploadBandwidthLimitKBps, forKey: "uploadBandwidthLimitKBps") }
    }

    // MARK: - Retention
    @Published var retentionDeleteAfterUpload: Bool {
        didSet { UserDefaults.standard.set(retentionDeleteAfterUpload, forKey: "retentionDeleteAfterUpload") }
    }
    @Published var retentionKeepLocalDays: Int {
        didSet { UserDefaults.standard.set(retentionKeepLocalDays, forKey: "retentionKeepLocalDays") }
    }
    @Published var retentionKeepThumbnails: Bool {
        didSet { UserDefaults.standard.set(retentionKeepThumbnails, forKey: "retentionKeepThumbnails") }
    }
    @Published var retentionProtectFavorites: Bool {
        didSet { UserDefaults.standard.set(retentionProtectFavorites, forKey: "retentionProtectFavorites") }
    }
    @Published var retentionGracePeriodHours: Int {
        didSet { UserDefaults.standard.set(retentionGracePeriodHours, forKey: "retentionGracePeriodHours") }
    }

    // MARK: - Event Recording
    @Published var eventRecordingEnabled: Bool {
        didSet { UserDefaults.standard.set(eventRecordingEnabled, forKey: "eventRecordingEnabled") }
    }
    @Published var eventClipDurationSeconds: Int {
        didSet { UserDefaults.standard.set(eventClipDurationSeconds, forKey: "eventClipDurationSeconds") }
    }
    @Published var autoUploadEventClips: Bool {
        didSet { UserDefaults.standard.set(autoUploadEventClips, forKey: "autoUploadEventClips") }
    }

    // MARK: - Daily Report
    @Published var dailyReportEnabled: Bool {
        didSet { UserDefaults.standard.set(dailyReportEnabled, forKey: "dailyReportEnabled") }
    }
    @Published var dailyReportHour: Int {
        didSet { UserDefaults.standard.set(dailyReportHour, forKey: "dailyReportHour") }
    }
    @Published var dailyReportMinute: Int {
        didSet { UserDefaults.standard.set(dailyReportMinute, forKey: "dailyReportMinute") }
    }

    // MARK: - Timelapse
    @Published var timelapseEnabled: Bool {
        didSet { UserDefaults.standard.set(timelapseEnabled, forKey: "timelapseEnabled") }
    }
    @Published var timelapseIntervalSeconds: Int {
        didSet { UserDefaults.standard.set(timelapseIntervalSeconds, forKey: "timelapseIntervalSeconds") }
    }
    @Published var timelapseFPS: Int {
        didSet { UserDefaults.standard.set(timelapseFPS, forKey: "timelapseFPS") }
    }
    @Published var autoUploadTimelapse: Bool {
        didSet { UserDefaults.standard.set(autoUploadTimelapse, forKey: "autoUploadTimelapse") }
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

        // Web Server
        webServerEnabled = UserDefaults.standard.bool(forKey: "webServerEnabled")
        webServerPort = UserDefaults.standard.object(forKey: "webServerPort") as? Int ?? 8765
        webServerBindAddress = UserDefaults.standard.string(forKey: "webServerBindAddress") ?? "127.0.0.1"

        // Storage Provider
        activeStorageProviderType = UserDefaults.standard.string(forKey: "activeStorageProviderType") ?? "none"
        localFolderPath = UserDefaults.standard.string(forKey: "localFolderPath") ?? ""
        mountedFolderPath = UserDefaults.standard.string(forKey: "mountedFolderPath") ?? ""
        googleDriveFolderID = UserDefaults.standard.string(forKey: "googleDriveFolderID") ?? ""
        googleDriveClientID = UserDefaults.standard.string(forKey: "googleDriveClientID") ?? ""
        // googleDriveClientSecret is stored in Keychain, not UserDefaults
        googleDriveRootFolderName = UserDefaults.standard.string(forKey: "googleDriveRootFolderName") ?? "MacMonitor"
        webdavURL = UserDefaults.standard.string(forKey: "webdavURL") ?? ""
        webdavUsername = UserDefaults.standard.string(forKey: "webdavUsername") ?? ""
        webdavBasePath = UserDefaults.standard.string(forKey: "webdavBasePath") ?? "/"
        allowInsecureWebDAV = UserDefaults.standard.bool(forKey: "allowInsecureWebDAV")

        // Upload
        autoUploadPhotos = UserDefaults.standard.bool(forKey: "autoUploadPhotos")
        autoUploadVideos = UserDefaults.standard.bool(forKey: "autoUploadVideos")
        uploadMaxConcurrent = UserDefaults.standard.object(forKey: "uploadMaxConcurrent") as? Int ?? 1
        uploadMaxRetries = UserDefaults.standard.object(forKey: "uploadMaxRetries") as? Int ?? 3
        uploadBandwidthLimitKBps = UserDefaults.standard.object(forKey: "uploadBandwidthLimitKBps") as? Int ?? 0

        // Retention
        retentionDeleteAfterUpload = UserDefaults.standard.bool(forKey: "retentionDeleteAfterUpload")
        retentionKeepLocalDays = UserDefaults.standard.object(forKey: "retentionKeepLocalDays") as? Int ?? 7
        retentionKeepThumbnails = UserDefaults.standard.object(forKey: "retentionKeepThumbnails") as? Bool ?? true
        retentionProtectFavorites = UserDefaults.standard.object(forKey: "retentionProtectFavorites") as? Bool ?? true
        retentionGracePeriodHours = UserDefaults.standard.object(forKey: "retentionGracePeriodHours") as? Int ?? 24

        // Event Recording
        eventRecordingEnabled = UserDefaults.standard.bool(forKey: "eventRecordingEnabled")
        eventClipDurationSeconds = UserDefaults.standard.object(forKey: "eventClipDurationSeconds") as? Int ?? 20
        autoUploadEventClips = UserDefaults.standard.bool(forKey: "autoUploadEventClips")

        // Daily Report
        dailyReportEnabled = UserDefaults.standard.bool(forKey: "dailyReportEnabled")
        dailyReportHour = UserDefaults.standard.object(forKey: "dailyReportHour") as? Int ?? 23
        dailyReportMinute = UserDefaults.standard.object(forKey: "dailyReportMinute") as? Int ?? 55

        // Timelapse
        timelapseEnabled = UserDefaults.standard.bool(forKey: "timelapseEnabled")
        timelapseIntervalSeconds = UserDefaults.standard.object(forKey: "timelapseIntervalSeconds") as? Int ?? 60
        timelapseFPS = UserDefaults.standard.object(forKey: "timelapseFPS") as? Int ?? 30
        autoUploadTimelapse = UserDefaults.standard.bool(forKey: "autoUploadTimelapse")
    }
}
