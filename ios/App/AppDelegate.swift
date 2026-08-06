import UIKit
import UserNotifications
import WidgetKit

extension Notification.Name {
    static let didRegisterPushToken = Notification.Name("didRegisterPushToken")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var latestDeviceToken: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task {
            let granted = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted == true {
                await MainActor.run { application.registerForRemoteNotifications() }
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        Self.latestDeviceToken = token
        NotificationCenter.default.post(name: .didRegisterPushToken, object: token)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            do {
                let previous = await ReminderStore.shared.cached()
                let refreshed = try await ReminderStore.shared.refresh()
                WidgetCenter.shared.reloadAllTimelines()
                await ReminderLiveActivityController.sync(reminders: refreshed)
                completionHandler(previous == refreshed ? .noData : .newData)
            } catch {
                completionHandler(.failed)
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Banner uses system notification chrome (full-width clear glass when
        // the user has Clear enabled). Payload is body-only — no title header.
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let reminders = await ReminderStore.shared.cached()
        await ReminderLiveActivityController.sync(reminders: reminders)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
