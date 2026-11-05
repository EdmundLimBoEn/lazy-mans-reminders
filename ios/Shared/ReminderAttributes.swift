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
        /// When positive, the final line is our generated footer, not reminder text.
        /// Optional so pre-metadata payloads remain decodable without interpreting text.
        var hiddenLineCount: Int? = nil
    }
}

enum ReminderActivityPresentation {
    /// Flatten reminder text into display lines for the Live Activity banner.
    static let activityPayloadByteLimit = 4096

    static func lines(from reminders: [Reminder]) -> [String] {
        state(from: reminders).lines
    }

    static func state(from reminders: [Reminder],
                      limit: Int = ReminderBoardLimits.lockScreenMaxLines) -> ReminderAttributes.ContentState {
        let originals = flattened(from: reminders.filter { !$0.isDone })
        var state = cappedState(.init(lines: originals, hiddenLineCount: 0), limit: max(1, limit))
        if encodedBytes(state) > activityPayloadByteLimit {
            let originals = originalLines(state)
            let hidden = state.hiddenLineCount ?? 0
            var fitted = originals.map { _ in "…" }
            for index in originals.indices {
                fitted[index] = longestFitting(originals[index]) { candidate in
                    var next = fitted
                    next[index] = candidate
                    return encodedBytes(makeState(next, hidden: hidden)) <= activityPayloadByteLimit
                }
            }
            state = makeState(fitted, hidden: hidden)
        }
        return state
    }

    static func cappedState(_ state: ReminderAttributes.ContentState, limit: Int) -> ReminderAttributes.ContentState {
        let visible = originalLines(state)
        let hidden = max(0, state.hiddenLineCount ?? 0)
        let cap = max(1, limit)
        guard visible.count + (hidden > 0 ? 1 : 0) > cap else { return state }
        let kept = Array(visible.prefix(max(0, cap - 1)))
        return makeState(kept, hidden: hidden + visible.count - kept.count)
    }

    private static func originalLines(_ state: ReminderAttributes.ContentState) -> [String] {
        (state.hiddenLineCount ?? 0) > 0 ? Array(state.lines.dropLast()) : state.lines
    }

    private static func makeState(_ visible: [String], hidden: Int) -> ReminderAttributes.ContentState {
        .init(lines: visible + (hidden > 0 ? ["+\(hidden) more"] : []), hiddenLineCount: hidden)
    }

    static func surfaceLines(_ state: ReminderAttributes.ContentState, limit: Int) -> [String] {
        let capped = cappedState(state, limit: limit)
        return capped.lines.isEmpty ? ["Nothing to remember"] : capped.lines
    }

    /// Widget-facing lines including the empty-state placeholder.
    static func displayLines(
        from reminders: [Reminder]?,
        limit: Int = ReminderBoardLimits.lockScreenMaxLines
    ) -> [String] {
        guard let reminders else { return ["Couldn’t Load Board"] }
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

    /// Keep an explicit overflow row when a surface has less room than the board.
    static func surfaceLines(_ lines: [String], limit: Int) -> [String] {
        capped(lines.isEmpty ? ["Nothing to remember"] : lines, limit: max(1, limit))
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

    private static func encodedBytes(_ state: ReminderAttributes.ContentState) -> Int {
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
