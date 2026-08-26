import Foundation

/// Board capacity follows the phone-measured Lock Screen Live Activity budget.
enum ReminderBoardLimits {
    /// Active reminders allowed — same as what fits on this phone’s banner.
    static var maxActive: Int { LockScreenLineBudget.cachedMaxLines }

    /// Lines shown in the Live Activity (same budget).
    static var lockScreenMaxLines: Int { LockScreenLineBudget.cachedMaxLines }

    static let postItHint =
        "Hint: This board is more like a post-it note. Combine reminders into one line, or find other ways to keep it short."

    static func isAtCapacity(_ activeCount: Int) -> Bool {
        activeCount >= maxActive
    }
}
