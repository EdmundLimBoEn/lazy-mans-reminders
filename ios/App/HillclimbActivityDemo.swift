#if DEBUG
import ActivityKit
import Foundation

/// Offline, explicit opt-in. Only IDs created here may be ended by this helper.
enum HillclimbActivityDemo {
    private static let ownedKey = "hillclimb.activity.ownedIDs"
    @MainActor static func runIfRequested() async {
        guard HillclimbDemo.mode == .activity else { return }
        precondition(Bundle.main.bundleIdentifier == "systems.edmundlim.NotepadHillclimb"
            && AppConfig.appGroupID == "group.systems.edmundlim.NotepadHillclimb")
        let defaults = UserDefaults.standard
        let owned = defaults.stringArray(forKey: ownedKey) ?? []
        for activity in Activity<ReminderAttributes>.activities where owned.contains(activity.id) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        defaults.set([], forKey: ownedKey)
        guard HillclimbDemo.argument("--hillclimb-activity") != "end" else { return }
        let long = HillclimbDemo.argument("--hillclimb-activity") == "long"
        let lines = (1...8).map { index in
            "Demo \(index): " + (long
                ? String(repeating: "Review the sample notes and gather the details for tomorrow. ", count: 4)
                : "Review the sample notes.")
        }
        let multiline = HillclimbDemo.argument("--hillclimb-activity") == "multiline"
        let reminders = [Reminder(id: UUID(), userID: UUID(),
            text: (1...10).map { "Demo \($0): Review the sample notes." }.joined(separator: "\n"),
            sortOrder: 0, isDone: false, createdAt: .now)]
        let state = multiline ? ReminderActivityPresentation.state(from: reminders, limit: 6)
            : ReminderAttributes.ContentState(lines: lines)
        do {
            let activity = try Activity.request(attributes: ReminderAttributes(),
                content: ActivityContent(state: state, staleDate: nil), pushType: nil)
            defaults.set([activity.id], forKey: ownedKey)
            record(["status": "requested", "id": activity.id, "lines": state.lines, "hiddenLineCount": state.hiddenLineCount ?? 0,
                    "authorization": ActivityAuthorizationInfo().areActivitiesEnabled])
        } catch {
            record(["status": "failed", "error": String(describing: error)])
        }
    }
    private static func record(_ value: [String: Any]) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("hillclimb-activity.json")
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
#endif
