import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    /// Only request permission if the user has enabled notifications in Settings
    /// and we haven't already determined the authorization status.
    func requestPermissionIfNeeded() {
        guard SettingsStore.shared.enableNotifications else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, error in
                if let error {
                    ActivityLogManager.shared.warning(.notification, "Notification permission request failed", detail: error.localizedDescription)
                }
            }
        }
    }

    func sendNotification(title: String, body: String, category: String? = nil) {
        guard SettingsStore.shared.enableNotifications else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                ActivityLogManager.shared.warning(.notification, "Notification not authorized", detail: "Status: \(settings.authorizationStatus.rawValue)")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if let category {
                content.categoryIdentifier = category
            }
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
