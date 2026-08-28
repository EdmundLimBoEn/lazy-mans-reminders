import ActivityKit
import Foundation

extension Notification.Name {
    static let didRegisterPushToStartToken = Notification.Name("didRegisterPushToStartToken")
    static let didRegisterActivityPushToken = Notification.Name("didRegisterActivityPushToken")
}

/// Keeps one Live Activity in sync with the active reminder board.
/// Lock Screen presentation is a full-width clear-glass banner (notification
/// proportions) with body text only — no header row or app icon in our layout.
enum ReminderLiveActivityController {
    private static let lock = NSLock()
    private static var observedActivityIDs = Set<String>()
    private static var didStartObserving = false

    static func startObservingTokens() {
        lock.lock()
        let shouldStart = !didStartObserving
        didStartObserving = true
        lock.unlock()
        guard shouldStart else { return }

        for activity in Activity<ReminderAttributes>.activities {
            observe(activity)
        }
        Task { await observePushToStartTokens() }
        Task { await observeActivityList() }
    }

    @MainActor
    static func sync(reminders: [Reminder]) async {
        startObservingTokens()
        let lines = ReminderActivityPresentation.lines(from: reminders)
        let state = ReminderAttributes.ContentState(lines: lines)
        let existing = Activity<ReminderAttributes>.activities
        let staleDate = Date().addingTimeInterval(8 * 60 * 60)

        switch LiveActivityPolicy.action(
            lineCount: lines.count,
            activityExists: !existing.isEmpty
        ) {
        case .none:
            return
        case .end:
            for activity in existing {
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        case .update:
            let content = ActivityContent(state: state, staleDate: staleDate)
            guard let first = existing.first else { return }
            await first.update(content)
            for activity in existing where activity.id != first.id {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        case .start:
            let content = ActivityContent(state: state, staleDate: staleDate)
            do {
                // pushType: .token so the server can update or replace this
                // banner after Apple's 8h cap without opening the app.
                let activity = try Activity.request(
                    attributes: ReminderAttributes(),
                    content: content,
                    pushType: .token
                )
                observe(activity)
            } catch {
                print("Reminder Live Activity request failed: \(error.localizedDescription)")
            }
        }
    }

    private static func observePushToStartTokens() async {
        guard #available(iOS 17.2, *) else { return }
        for await tokenData in Activity<ReminderAttributes>.pushToStartTokenUpdates {
            NotificationCenter.default.post(
                name: .didRegisterPushToStartToken,
                object: hex(tokenData)
            )
        }
    }

    private static func observeActivityList() async {
        for await activity in Activity<ReminderAttributes>.activityUpdates {
            observe(activity)
        }
    }

    private static func observe(_ activity: Activity<ReminderAttributes>) {
        lock.lock()
        let isNew = observedActivityIDs.insert(activity.id).inserted
        lock.unlock()
        guard isNew else { return }

        Task {
            for await tokenData in activity.pushTokenUpdates {
                NotificationCenter.default.post(
                    name: .didRegisterActivityPushToken,
                    object: hex(tokenData)
                )
            }
        }
        Task {
            for await state in activity.activityStateUpdates {
                guard state == .ended else { continue }
                lock.lock()
                observedActivityIDs.remove(activity.id)
                lock.unlock()
                let othersActive = Activity<ReminderAttributes>.activities.contains {
                    $0.id != activity.id && $0.activityState == .active
                }
                guard !othersActive else { continue }
                let reminders = await ReminderStore.shared.cached()
                await sync(reminders: reminders)
            }
        }
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
