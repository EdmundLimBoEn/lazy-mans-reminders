import Foundation

/// Board capacity follows the phone-measured Lock Screen Live Activity budget.
enum ReminderBoardLimits {
    /// Active reminders allowed — same as what fits on this phone’s banner.
    static var maxActive: Int { LockScreenLineBudget.cachedMaxLines }

    /// Lines shown in the Live Activity (same budget).
    static var lockScreenMaxLines: Int { LockScreenLineBudget.cachedMaxLines }

    static let postItHint =
        "Hint: This app is more like a post it note, you can combine different reminders into 1 line, or find other ways to optimise"

    static func isAtCapacity(_ activeCount: Int) -> Bool {
        activeCount >= maxActive
    }
}
