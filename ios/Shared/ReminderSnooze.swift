import Foundation

/// Local wall-clock choices; inject the calendar (including its time zone) for tests.
enum ReminderSnooze: CaseIterable {
    case threeHours, tonight, tomorrow

    var title: String {
        switch self {
        case .threeHours: return "3 hours"
        case .tonight: return "Tonight"
        case .tomorrow: return "Tomorrow"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .threeHours: return "Snooze for 3 hours"
        case .tonight: return "Snooze until tonight"
        case .tomorrow: return "Snooze until tomorrow"
        }
    }

    func until(now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .threeHours:
            return now.addingTimeInterval(3 * 60 * 60)
        case .tonight:
            let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)!
            return evening < now ? now.addingTimeInterval(60 * 60) : evening
        case .tomorrow:
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextDay)!
        }
    }
}
