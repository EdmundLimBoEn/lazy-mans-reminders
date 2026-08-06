import ActivityKit
import Foundation

/// Lock Screen Live Activity that presents reminders as a full-width
/// notification-style banner (body text only — no title / app-icon chrome).
struct ReminderAttributes: ActivityAttributes {
    /// Empty fixed attributes; all visible content lives in `ContentState`
    /// so updates can replace the full line list without restarting.
    struct ContentState: Codable, Hashable {
        /// One line per reminder (newlines already split).
        var lines: [String]
    }
}

enum ReminderActivityPresentation {
    static func lines(from reminders: [Reminder]) -> [String] {
        let active = reminders.filter { !$0.isDone }
        if active.isEmpty { return [] }
        return active.flatMap { reminder in
            reminder.text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }
}
