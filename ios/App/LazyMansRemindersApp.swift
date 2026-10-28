import SwiftUI

@main
struct LazyMansRemindersApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .onOpenURL { url in
                    Task { await auth.handle(url: url) }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                BackgroundBoardRefresh.schedule()
            }
        }
    }
}
