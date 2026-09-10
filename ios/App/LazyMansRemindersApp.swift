import SwiftUI

@main
struct LazyMansRemindersApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.auth)
                .onOpenURL { url in
                    Task { await appDelegate.auth.handle(url: url) }
                }
        }
    }
}
