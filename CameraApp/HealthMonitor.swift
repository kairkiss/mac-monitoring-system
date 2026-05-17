import Foundation
import AppKit

final class HealthMonitor: ObservableObject {
    static let shared = HealthMonitor()

    @Published var lastHealthCheck: Date?
    @Published var alerts: [HealthAlert] = []

    private var checkTimer: Timer?
    private var telegramFailureCount = 0
    private var lastFrameTime: Date = Date()
    private var frameWatchdogTimer: Timer?

    private var diskCooldownUntil: Date = .distantPast
    private var cameraCooldownUntil: Date = .distantPast
    private var telegramCooldownUntil: Date = .distantPast
    private let cooldownDuration: TimeInterval = 300  // 5 minutes between same alert

    private init() {
        setupObservers()
    }

    // MARK: - Setup

    func startMonitoring() {
        guard SettingsStore.shared.enableHealthMonitor else { return }
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
        startFrameWatchdog()
        performHealthCheck()
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
        frameWatchdogTimer?.invalidate()
        frameWatchdogTimer = nil
    }

    private func setupObservers() {
        // Track telegram failures
        NotificationCenter.default.addObserver(
            self, selector: #selector(telegramDidFail),
            name: .telegramSendFailed, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(telegramDidSucceed),
            name: .telegramSendSucceeded, object: nil
        )
    }

    private func startFrameWatchdog() {
        frameWatchdogTimer?.invalidate()
        frameWatchdogTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkFrameHealth()
        }
    }

    // MARK: - Health Checks

    func performHealthCheck() {
        lastHealthCheck = Date()
        checkDiskSpace()
        checkCameraStatus()
    }

    private func checkDiskSpace() {
        guard SettingsStore.shared.notifyLowDisk else { return }
        guard Date() >= diskCooldownUntil else { return }

        let thresholdMB = Int64(SettingsStore.shared.lowDiskThresholdMB)
        guard !MediaLibraryManager.shared.hasEnoughDiskSpace(minimumMB: thresholdMB) else { return }

        diskCooldownUntil = Date().addingTimeInterval(cooldownDuration)
        let alert = HealthAlert(
            type: .lowDisk,
            message: Strings.notifyLowDisk,
            timestamp: Date()
        )
        addAlert(alert)
        sendNotification(title: Strings.healthMonitor, body: Strings.notifyLowDisk)
        ActivityLogManager.shared.warning(.health, Strings.notifyLowDisk)
    }

    private func checkCameraStatus() {
        guard SettingsStore.shared.notifyCameraDisconnect else { return }
        guard Date() >= cameraCooldownUntil else { return }

        let camera = CameraManager.shared
        if case .noCamera = camera.status {
            cameraCooldownUntil = Date().addingTimeInterval(cooldownDuration)
            let alert = HealthAlert(
                type: .cameraDisconnected,
                message: Strings.cameraDisconnected,
                timestamp: Date()
            )
            addAlert(alert)
            sendNotification(title: Strings.healthMonitor, body: Strings.cameraDisconnected)
            ActivityLogManager.shared.warning(.health, Strings.cameraDisconnected)
        }
    }

    private var frameWarningCooldownUntil: Date = .distantPast

    private func checkFrameHealth() {
        let camera = CameraManager.shared
        guard camera.status == .running else { return }
        guard Date() >= frameWarningCooldownUntil else { return }

        let elapsed = Date().timeIntervalSince(lastFrameTime)
        if elapsed > 30 {
            frameWarningCooldownUntil = Date().addingTimeInterval(cooldownDuration)
            let detail = String(format: "No frames received for %.0f seconds", elapsed)
            ActivityLogManager.shared.warning(.health, "Camera frame watchdog", detail: detail)
            if SettingsStore.shared.enableNotifications && SettingsStore.shared.notifyOnErrors {
                sendNotification(title: Strings.healthMonitor, body: detail)
            }
        }
    }

    func recordFrameReceived() {
        lastFrameTime = Date()
    }

    // MARK: - Telegram Tracking

    @objc private func telegramDidFail() {
        telegramFailureCount += 1
        guard SettingsStore.shared.notifyTelegramFailure else { return }
        guard telegramFailureCount >= 3 else { return }
        guard Date() >= telegramCooldownUntil else { return }

        telegramCooldownUntil = Date().addingTimeInterval(cooldownDuration)
        let alert = HealthAlert(
            type: .telegramFailure,
            message: "\(Strings.notifyTelegramFailure) (\(telegramFailureCount) consecutive failures)",
            timestamp: Date()
        )
        addAlert(alert)
        sendNotification(title: Strings.healthMonitor, body: Strings.notifyTelegramFailure)
        ActivityLogManager.shared.warning(.health, Strings.notifyTelegramFailure, detail: "\(telegramFailureCount) consecutive failures")
    }

    @objc private func telegramDidSucceed() {
        telegramFailureCount = 0
    }

    // MARK: - Alerts

    private func addAlert(_ alert: HealthAlert) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.alerts.insert(alert, at: 0)
            if self.alerts.count > 50 {
                self.alerts = Array(self.alerts.prefix(50))
            }
        }
    }

    func clearAlerts() {
        alerts.removeAll()
    }

    // MARK: - Notifications

    private func sendNotification(title: String, body: String) {
        NotificationManager.shared.sendNotification(title: title, body: body)
    }
}

struct HealthAlert: Identifiable {
    let id = UUID()
    let type: HealthAlertType
    let message: String
    let timestamp: Date
}

enum HealthAlertType {
    case lowDisk
    case cameraDisconnected
    case telegramFailure
    case frameAnomaly
}

// MARK: - Notification Names

extension Notification.Name {
    static let telegramSendFailed = Notification.Name("telegramSendFailed")
    static let telegramSendSucceeded = Notification.Name("telegramSendSucceeded")
}
