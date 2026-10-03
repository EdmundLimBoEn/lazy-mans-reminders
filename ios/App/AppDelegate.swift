import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
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
        _ = AuthManager.shared.pushRegistration
        BackgroundBoardRefresh.register()
        // Register on every launch, including an ActivityKit background launch.
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().setNotificationCategories([
            NotificationAccessPolicy.makeReminderCategory()
        ])
        NotificationCenter.default.addObserver(
            forName: .didRegisterPushToStartToken,
            object: nil,
            queue: .main
        ) { notification in
            guard let token = notification.object as? String else { return }
            Task { @MainActor in
                AuthManager.shared.pushRegistration.recordPushToStartToken(token)
                await AuthManager.shared.registerLiveActivityTokens()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .didRegisterActivityPushToken,
            object: nil,
            queue: .main
        ) { notification in
            guard let token = notification.object as? String else { return }
            Task { @MainActor in
                AuthManager.shared.pushRegistration.recordActivityToken(token)
                await AuthManager.shared.registerLiveActivityTokens()
            }
        }
        ReminderLiveActivityController.startObservingTokens()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        Task { await AuthManager.shared.registerDevice(token: token) }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundBoardRefresh.schedule()
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
        Task {
            do {
                let refreshed = try await ReminderStore.shared.refresh()
                await ReminderBoardSync.apply(refreshed)
            } catch {
                let cached = await ReminderStore.shared.cached()
                await ReminderBoardSync.apply(cached)
            }
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
