import ActivityKit
import Foundation

/// Keeps one Live Activity in sync with the active reminder board.
/// Lock Screen presentation is a full-width clear-glass banner (notification
/// proportions) with body text only — no header row or app icon in our layout.
enum ReminderLiveActivityController {
    @MainActor
    static func sync(reminders: [Reminder]) async {
        let lines = ReminderActivityPresentation.lines(from: reminders)
        let state = ReminderAttributes.ContentState(lines: lines)

        if lines.isEmpty {
            for activity in Activity<ReminderAttributes>.activities {
                await activity.end(
                    ActivityContent(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
            return
        }

        let content = ActivityContent(state: state, staleDate: nil)

        if let existing = Activity<ReminderAttributes>.activities.first {
            await existing.update(content)
            // End any extras so we never stack duplicate banners.
            for activity in Activity<ReminderAttributes>.activities where activity.id != existing.id {
                await activity.end(content, dismissalPolicy: .immediate)
            }
            return
        }

        do {
            _ = try Activity.request(
                attributes: ReminderAttributes(),
                content: content,
                pushType: nil
            )
        } catch {
            // Activities can be disabled in Settings; fail soft.
            print("Reminder Live Activity request failed: \(error.localizedDescription)")
        }
    }
}
