import SwiftUI

@main
struct LazyMansRemindersApp: App {
    @Environment(\.scenePhase) private var scenePhase
#if DEBUG
    @UIApplicationDelegateAdaptor(HillclimbLaunchDelegate.self) private var appDelegate
#else
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#endif
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .onOpenURL { url in
#if DEBUG
                    guard !HillclimbDemo.isActive else { return }
#endif
                    Task { await auth.handle(url: url) }
                }
        }
        .onChange(of: scenePhase) { _, phase in
#if DEBUG
            guard !HillclimbDemo.isActive else { return }
#endif
            if phase == .background {
                BackgroundBoardRefresh.schedule()
            }
        }
    }
}
