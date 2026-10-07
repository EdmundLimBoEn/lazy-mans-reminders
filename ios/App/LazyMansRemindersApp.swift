import SwiftUI

@main
struct LazyMansRemindersApp: App {
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
    }
}
