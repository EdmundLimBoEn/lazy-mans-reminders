import BackgroundTasks
import UIKit

@MainActor
enum BackgroundBoardRefresh {
    static let identifier = "systems.edmundlim.LazyMansReminders.board-refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in handle(refresh) }
        }
    }

    static func schedule() {
        guard UIApplication.shared.backgroundRefreshStatus == .available else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Board refresh scheduling failed: \(error.localizedDescription)")
        }
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()
        let work = Task { @MainActor in
            var success = false
            defer { task.setTaskCompleted(success: success) }
            do {
                try Task.checkCancellation()
                await AuthManager.shared.waitForRestoration()
                try Task.checkCancellation()
                await AuthManager.shared.registerLiveActivityTokens()
                let reminders = try await ReminderStore.shared.refresh()
                try Task.checkCancellation()
                await ReminderBoardSync.apply(reminders)
                success = true
            } catch {
                print("Background board refresh did not complete: \(error.localizedDescription)")
            }
        }
        task.expirationHandler = { work.cancel() }
    }
}
