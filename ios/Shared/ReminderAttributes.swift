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
    static let activityPayloadByteLimit = 4096

    static func lines(from reminders: [Reminder]) -> [String] {
        let active = reminders.filter { !$0.isDone }
        if active.isEmpty { return [] }
        return fitToByteBudget(
            capped(flattened(from: active), limit: ReminderBoardLimits.lockScreenMaxLines)
        )
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

    /// Lock Screen banner and expanded Dynamic Island lines from content state.
    /// Adds the empty placeholder and clips to the current device budget.
    static func presentedLines(_ lines: [String]) -> [String] {
        let source = lines.isEmpty ? ["Nothing to remember"] : lines
        return Array(source.prefix(ReminderBoardLimits.lockScreenMaxLines))
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

    private static func fitToByteBudget(_ lines: [String]) -> [String] {
        if encodedBytes(lines) <= activityPayloadByteLimit { return lines }
        var fitted = lines
        for index in stride(from: fitted.count - 1, through: 0, by: -1) {
            if encodedBytes(fitted) <= activityPayloadByteLimit { break }
            fitted[index] = longestFitting(fitted[index]) { candidate in
                var next = fitted
                next[index] = candidate
                return encodedBytes(next) <= activityPayloadByteLimit
            }
        }
        let kept = fitted.filter { !$0.isEmpty }
        if kept.contains(where: { $0.contains("…") }) { return kept }
        let marked = kept + ["…"]
        return encodedBytes(marked) <= activityPayloadByteLimit ? marked : kept
    }

    private static func longestFitting(
        _ text: String,
        fits: (String) -> Bool
    ) -> String {
        if fits(text) { return text }
        let points = Array(text)
        var low = 0
        var high = points.count
        var best = ""
        while low <= high {
            let mid = (low + high) / 2
            let candidate = mid >= points.count
                ? text
                : String(points.prefix(mid)) + "…"
            if fits(candidate) {
                best = candidate
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        if !best.isEmpty { return best }
        return fits("…") ? "…" : ""
    }

    private static func encodedBytes(_ lines: [String]) -> Int {
        let state = ReminderAttributes.ContentState(lines: lines)
        guard let content = try? JSONEncoder().encode(state),
              let attributes = try? JSONEncoder().encode(ReminderAttributes()) else { return Int.max }
        return content.count + attributes.count
    }

    private static func capped(_ flattened: [String], limit: Int) -> [String] {
        guard flattened.count > limit else { return flattened }
        let visible = Array(flattened.prefix(max(limit - 1, 0)))
        let overflow = flattened.count - visible.count
        return visible + ["+\(overflow) more"]
    }
}
