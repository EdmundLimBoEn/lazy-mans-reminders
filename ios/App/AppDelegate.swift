import Combine
import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let auth = AuthManager()
    private var subscriptions = Set<AnyCancellable>()
    private lazy var deviceRegistration = DeviceRegistrationCoordinator(
        readyToken: { [weak self] in
            guard self?.auth.session != nil else { return nil }
            return Self.latestDeviceToken
        },
        upload: { [weak self] token in await self?.auth.registerDevice(token: token) }
    )

    static var latestDeviceToken: String?
    static var latestPushToStartToken: String?
    static var latestActivityPushToken: String?

    static func requestPushIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
        case .authorized, .provisional, .ephemeral:
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        default:
            break
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationCenter.default.publisher(for: .didRegisterPushToStartToken)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                Self.latestPushToStartToken = notification.object as? String
                self?.reconcileDeviceRegistration()
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .didRegisterActivityPushToken)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                Self.latestActivityPushToken = notification.object as? String
                self?.reconcileDeviceRegistration()
            }
            .store(in: &subscriptions)
        auth.$session
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reconcileDeviceRegistration() }
            .store(in: &subscriptions)
        ReminderLiveActivityController.startObservingTokens()
        // APNs registration does not prompt for notification permission, and a
        // push-to-start background launch needs a fresh device token too.
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        Self.latestDeviceToken = token
        reconcileDeviceRegistration()
    }

    private func reconcileDeviceRegistration() {
        deviceRegistration.reconcile()
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
        // Banner uses system notification chrome (full-width clear glass when
        // the user has Clear enabled). Payload is body-only — no title header.
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let reminders = await ReminderStore.shared.cached()
        await ReminderBoardSync.apply(reminders)
    }
}

@MainActor
final class DeviceRegistrationCoordinator {
    private let readyToken: () -> String?
    private let upload: (String) async -> Void
    private var registrationTask: Task<Void, Never>?
    private var registrationPending = false

    init(readyToken: @escaping () -> String?, upload: @escaping (String) async -> Void) {
        self.readyToken = readyToken
        self.upload = upload
    }

    @discardableResult
    func reconcile() -> Task<Void, Never> {
        registrationPending = true
        if let registrationTask { return registrationTask }
        let task = Task {
            while registrationPending {
                registrationPending = false
                guard let token = readyToken() else { continue }
                await upload(token)
            }
            registrationTask = nil
        }
        registrationTask = task
        return task
    }
}
