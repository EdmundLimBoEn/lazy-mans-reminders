import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isRestoringSession {
                AccessibleProgressView("Restoring session")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if auth.session == nil {
                SignInView()
            } else {
                ReminderListView()
                    .id(auth.session?.user.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task(id: "\(auth.session?.accessToken ?? "")-\(auth.isRestoringSession)") {
            guard !auth.isRestoringSession else { return }
            await auth.syncLockScreenPrefs()
            if auth.session != nil {
                await AppDelegate.requestPushIfNeeded()
            }
            if let token = auth.pushRegistration.deviceToken {
                await auth.registerDevice(token: token)
            }
        }
        // Restore independently of the list's shared-session and drag/reorder guards.
        // Include readiness so a newly shared account cache gets another opportunity.
        .task(id: "\(scenePhase)-\(auth.session?.user.id.uuidString ?? "")-\(auth.isRestoringSession)-\(auth.isSharedSessionReady)") {
            guard scenePhase == .active, !auth.isRestoringSession,
                  let userID = auth.session?.user.id else { return }
            await ReminderBoardSync.restoreCachedBoard(for: userID)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, auth.session != nil, !auth.isRestoringSession else { return }
            Task {
                await AppDelegate.requestPushIfNeeded()
                if let token = auth.pushRegistration.deviceToken {
                    await auth.registerDevice(token: token)
                }
            }
        }
    }
}
