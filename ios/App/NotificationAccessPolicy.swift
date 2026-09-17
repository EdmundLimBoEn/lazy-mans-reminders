import UIKit
import UserNotifications

/// Notification permission, category, and foreground presentation rules.
enum NotificationAccessPolicy {
    enum Access: Equatable {
        case ask
        case allowed
        case blocked
    }

    static let reminderCategoryID = "reminder"
    static let hiddenPreviewsPlaceholder = "New reminder"
    static var authorizationOptions: UNAuthorizationOptions { [.alert, .sound] }
    static var foregroundPresentation: UNNotificationPresentationOptions { [] }

    static func access(for status: UNAuthorizationStatus) -> Access {
        switch status {
        case .notDetermined:
            return .ask
        case .authorized, .provisional, .ephemeral:
            return .allowed
        case .denied:
            return .blocked
        @unknown default:
            return .blocked
        }
    }

    static func shouldPrompt(isRestoringSession: Bool, status: UNAuthorizationStatus) -> Bool {
        !isRestoringSession && status == .notDetermined
    }

    static func opensSettings(_ access: Access) -> Bool {
        access == .blocked
    }

    static func value(_ access: Access) -> String {
        switch access {
        case .allowed:
            return "On"
        case .ask, .blocked:
            return "Off"
        }
    }

    static func footer(_ access: Access) -> String {
        switch access {
        case .allowed:
            return "New reminders from the web and agents appear as banners."
        case .ask:
            return "Allow notifications so new reminders can appear as banners."
        case .blocked:
            return "Notifications are off. Turn them on in Settings to get banners for new reminders."
        }
    }

    static func notificationSettingsURL() -> URL? {
        URL(string: UIApplication.openNotificationSettingsURLString)
    }

    static func makeReminderCategory() -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: reminderCategoryID,
            actions: [],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: hiddenPreviewsPlaceholder,
            options: []
        )
    }
}
