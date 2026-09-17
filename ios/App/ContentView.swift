import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isRestoringSession {
                ProgressView("Loading")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading")
            } else if auth.session == nil {
                SignInView()
            } else {
                ReminderListView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task(id: auth.session?.accessToken) {
            await auth.syncLockScreenPrefs()
            if auth.session != nil {
                await AppDelegate.requestPushIfNeeded()
            }
            if let token = AppDelegate.latestDeviceToken {
                await auth.registerDevice(token: token)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRegisterPushToken)) { notification in
            guard let token = notification.object as? String else { return }
            Task { await auth.registerDevice(token: token) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRegisterPushToStartToken)) { notification in
            AppDelegate.latestPushToStartToken = notification.object as? String
            Task { await auth.registerLiveActivityTokens() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRegisterActivityPushToken)) { notification in
            AppDelegate.latestActivityPushToken = notification.object as? String
            Task { await auth.registerLiveActivityTokens() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, auth.session != nil else { return }
            Task {
                await AppDelegate.requestPushIfNeeded()
                if let token = AppDelegate.latestDeviceToken {
                    await auth.registerDevice(token: token)
                }
            }
        }
    }
}
