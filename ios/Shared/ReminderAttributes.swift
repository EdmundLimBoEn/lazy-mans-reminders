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
    /// Flatten reminder text into display lines for the Live Activity banner.
    static func lines(from reminders: [Reminder]) -> [String] {
        let active = reminders.filter { !$0.isDone }
        if active.isEmpty { return [] }
        return capped(flattened(from: active), limit: ReminderBoardLimits.lockScreenMaxLines)
    }

    /// Widget-facing lines including the empty-state placeholder.
    static func displayLines(
        from reminders: [Reminder],
        limit: Int = ReminderBoardLimits.lockScreenMaxLines
    ) -> [String] {
        let active = reminders.filter { !$0.isDone }
        if active.isEmpty { return ["Nothing to remember"] }
        return capped(flattened(from: active), limit: limit)
    }

    static func previewLines(_ lines: [String], limit: Int = 6) -> [String] {
        capped(lines, limit: limit)
    }

    private static func flattened(from reminders: [Reminder]) -> [String] {
        reminders.flatMap { reminder in
            reminder.text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    private static func capped(_ flattened: [String], limit: Int) -> [String] {
        guard flattened.count > limit else { return flattened }
        let visible = Array(flattened.prefix(max(limit - 1, 0)))
        let overflow = flattened.count - visible.count
        return visible + ["+\(overflow) more"]
    }
}
