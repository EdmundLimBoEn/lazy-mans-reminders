import UIKit
import UserNotifications

extension Notification.Name {
    static let didRegisterPushToken = Notification.Name("didRegisterPushToken")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var latestDeviceToken: String?
    static var latestPushToStartToken: String?
    static var latestActivityPushToken: String?

    static func requestPushIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if NotificationAccessPolicy.shouldPrompt(
            isRestoringSession: false,
            status: settings.authorizationStatus
        ) {
            let granted = (try? await center.requestAuthorization(
                options: NotificationAccessPolicy.authorizationOptions
            )) ?? false
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
            return
        }
        if NotificationAccessPolicy.access(for: settings.authorizationStatus) == .allowed {
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().setNotificationCategories([
            NotificationAccessPolicy.makeReminderCategory()
        ])
        NotificationCenter.default.addObserver(
            forName: .didRegisterPushToStartToken,
            object: nil,
            queue: .main
        ) { notification in
            Self.latestPushToStartToken = notification.object as? String
        }
        NotificationCenter.default.addObserver(
            forName: .didRegisterActivityPushToken,
            object: nil,
            queue: .main
        ) { notification in
            Self.latestActivityPushToken = notification.object as? String
        }
        ReminderLiveActivityController.startObservingTokens()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        Self.latestDeviceToken = token
        NotificationCenter.default.post(name: .didRegisterPushToken, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
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
                await ReminderBoardSync.apply(refreshed)
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
        do {
            let refreshed = try await ReminderStore.shared.refresh()
            await ReminderBoardSync.apply(refreshed)
        } catch {
            let cached = await ReminderStore.shared.cached()
            await ReminderBoardSync.apply(cached)
        }
        return NotificationAccessPolicy.foregroundPresentation
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        do {
            let refreshed = try await ReminderStore.shared.refresh()
            await ReminderBoardSync.apply(refreshed)
        } catch {
            let cached = await ReminderStore.shared.cached()
            await ReminderBoardSync.apply(cached)
        }
    }
}
