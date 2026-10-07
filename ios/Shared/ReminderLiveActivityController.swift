import ActivityKit
import Foundation

extension Notification.Name {
    static let didRegisterPushToStartToken = Notification.Name("didRegisterPushToStartToken")
    static let didRegisterActivityPushToken = Notification.Name("didRegisterActivityPushToken")
}

@MainActor
enum ReminderLiveActivityController {
    private static var observedActivityIDs = Set<String>()
    private static var didStartObserving = false
    private static var selectedActivityID: String?
    private static var isEndingBoard = false
    private static let selectionKey = "live-activity-selection"
    private static let knownIDsKey = "live-activity-known-ids"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID)!
    }

    private static var activeActivities: [Activity<ReminderAttributes>] {
        Activity<ReminderAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    static func startObservingTokens() {
        guard !didStartObserving else { return }
        didStartObserving = true
        let existing = activeActivities
        selectedActivityID = LiveActivityPolicy.selectedActivityID(
            currentIDs: existing.map(\.id),
            knownIDs: defaults.stringArray(forKey: knownIDsKey) ?? [],
            previousSelection: defaults.string(forKey: selectionKey)
        )
        persistSelection()
        for activity in existing { observe(activity) }
        Task { await observePushToStartTokens() }
        Task { await observeActivityList() }
    }

    static func sync(reminders: [Reminder]) async {
        startObservingTokens()
        let lines = ReminderActivityPresentation.lines(from: reminders)
        let state = ReminderAttributes.ContentState(lines: lines)
        let existing = activeActivities
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(8 * 60 * 60))
        let hasActivity = lines.isEmpty
            ? !Activity<ReminderAttributes>.activities.isEmpty : !existing.isEmpty
        switch LiveActivityPolicy.action(lineCount: lines.count, activityExists: hasActivity) {
        case .none:
            return
        case .end:
            isEndingBoard = true
            defer { isEndingBoard = false }
            for activity in Activity<ReminderAttributes>.activities {
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
            }
        case .update:
            // The server retires the old banner after acknowledging the new token.
            // Activity.activities has no ordering guarantee; ending all but .first
            // can destroy the replacement during this handoff.
            for activity in existing { await activity.update(content) }
        case .start:
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                let activity = try Activity.request(
                    attributes: ReminderAttributes(), content: content, pushType: .token
                )
                select(activity)
                observe(activity)
            } catch {
                print("Reminder Live Activity request failed: \(error.localizedDescription)")
            }
        }
    }

    private static func observePushToStartTokens() async {
        guard #available(iOS 17.2, *) else { return }
        for await token in Activity<ReminderAttributes>.pushToStartTokenUpdates {
            NotificationCenter.default.post(name: .didRegisterPushToStartToken, object: hex(token))
        }
    }

    private static func observeActivityList() async {
        for await activity in Activity<ReminderAttributes>.activityUpdates {
            guard !observedActivityIDs.contains(activity.id),
                  activity.activityState == .active || activity.activityState == .stale else { continue }
            select(activity)
            observe(activity)
        }
    }

    private static func select(_ activity: Activity<ReminderAttributes>) {
        selectedActivityID = activity.id
        persistSelection()
    }

    private static func persistSelection() {
        defaults.set(selectedActivityID, forKey: selectionKey)
        defaults.set(activeActivities.map(\.id), forKey: knownIDsKey)
    }

    private static func observe(_ activity: Activity<ReminderAttributes>) {
        guard observedActivityIDs.insert(activity.id).inserted else { return }
        Task {
            for await token in activity.pushTokenUpdates {
                guard selectedActivityID == activity.id,
                      activity.activityState == .active || activity.activityState == .stale else { continue }
                NotificationCenter.default.post(name: .didRegisterActivityPushToken, object: hex(token))
            }
        }
        Task {
            for await state in activity.activityStateUpdates {
                guard state == .ended || state == .dismissed else { continue }
                observedActivityIDs.remove(activity.id)
                // Reconcile on the next explicit board sync. Restarting here can
                // resurrect a banner just ended by a remote clear or sign-out.
                if selectedActivityID == activity.id { selectedActivityID = nil }
                if !isEndingBoard { persistSelection() }
                return
            }
        }
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
