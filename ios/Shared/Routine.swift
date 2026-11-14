import Foundation

struct Routine: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    var intervalDays: Int
    var startDate: String
    var localTime: String
    var timezone: String
    var enabled: Bool
    var nextRunAt: Date

    enum CodingKeys: String, CodingKey {
        case id, text, timezone, enabled
        case intervalDays = "interval_days"
        case startDate = "start_date"
        case localTime = "local_time"
        case nextRunAt = "next_run_at"
    }
}

/// Calendar-only arithmetic mirrors web/src/lib/routines.ts, independent of the phone's timezone.
enum RoutineSchedule {
    static let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func localDate(_ date: Date = Date(), timezone: TimeZone = .current) -> String {
        var calendar = calendar
        calendar.timeZone = timezone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    static func date(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), localDate(date, timezone: calendar.timeZone) == value else {
            return nil
        }
        return date
    }

    static func weekday(_ date: String) -> Int {
        calendar.component(.weekday, from: self.date(date)!) - 1
    }

    static func weeklyStartDate(weekday: Int, timezone: String, now: Date = Date()) throws -> String {
        guard let zone = TimeZone(identifier: timezone) else { throw RoutineValidationError.timezone }
        guard (0...6).contains(weekday) else { throw RoutineValidationError.schedule }
        let today = date(localDate(now, timezone: zone))!
        let offset = (weekday - (calendar.component(.weekday, from: today) - 1) + 7) % 7
        return localDate(calendar.date(byAdding: .day, value: offset, to: today)!, timezone: calendar.timeZone)
    }

    static func summary(_ routine: Routine) -> String {
        let cadence: String
        if routine.intervalDays == 7 {
            cadence = "Every \(weekdays[weekday(routine.startDate)])"
        } else if routine.intervalDays == 1 {
            cadence = "Every day"
        } else {
            cadence = "Every \(routine.intervalDays) days"
        }
        return "\(cadence) at \(routine.localTime.prefix(5)) · \(routine.timezone)"
    }

    static func status(_ routine: Routine, locale: Locale = .current) -> String {
        guard routine.enabled else { return "Paused" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: routine.timezone)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Next: \(formatter.string(from: routine.nextRunAt)) · \(routine.timezone)"
    }
}

enum RoutineValidationError: LocalizedError {
    case emptyText, tooLong, timezone, days, schedule

    var errorDescription: String? {
        switch self {
        case .emptyText: return "Reminder text is empty."
        case .tooLong: return "Keep each reminder to 500 characters."
        case .timezone: return "Enter a valid timezone, such as Asia/Singapore."
        case .days: return "Enter a number of days from 1 to 365."
        case .schedule: return "Enter a valid start date and time."
        }
    }
}

/// Only client-writable schedule columns; no computed next_run_at or owner on updates.
struct RoutineValues: Encodable, Equatable {
    let text: String
    let intervalDays: Int
    let startDate: String
    let localTime: String
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case text, timezone
        case intervalDays = "interval_days"
        case startDate = "start_date"
        case localTime = "local_time"
    }
}

struct RoutineDraft {
    enum Cadence: String, CaseIterable {
        case daily = "Every day", weekly = "Every week", days = "Every N days"
    }

    var text = ""
    var cadence: Cadence = .daily {
        didSet { if cadence != oldValue { weeklyStartChanged = true } }
    }
    var weekday = 1 {
        didSet { if weekday != oldValue { weeklyStartChanged = true } }
    }
    var days = "2"
    var startDate: String
    var hour = 19
    var minute = 0
    var timezone: String {
        didSet { if timezone != oldValue { weeklyStartChanged = true } }
    }
    private(set) var weeklyStartChanged = false
    let original: Routine?

    init(routine: Routine? = nil, now: Date = Date(), timezone: TimeZone = .current) {
        original = routine
        self.timezone = routine?.timezone ?? timezone.identifier
        startDate = routine?.startDate ?? RoutineSchedule.localDate(now, timezone: timezone)
        if let routine {
            text = routine.text
            cadence = routine.intervalDays == 7 ? .weekly : routine.intervalDays == 1 ? .daily : .days
            weekday = RoutineSchedule.weekday(routine.startDate)
            days = String(routine.intervalDays)
            let time = routine.localTime.split(separator: ":")
            hour = Int(time[0]) ?? 19
            minute = Int(time[1]) ?? 0
        }
    }

    func values(now: Date = Date()) throws -> RoutineValues {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RoutineValidationError.emptyText }
        guard trimmed.unicodeScalars.count <= 500 else { throw RoutineValidationError.tooLong }
        guard let zone = TimeZone(identifier: timezone) else { throw RoutineValidationError.timezone }
        guard (0...23).contains(hour), (0...59).contains(minute) else { throw RoutineValidationError.schedule }
        let interval: Int
        let start: String
        switch cadence {
        case .daily:
            interval = 1
            // Preserve an existing daily routine's first firing for a text/time-only edit.
            start = original?.intervalDays == 1 && !weeklyStartChanged
                ? startDate : RoutineSchedule.localDate(now, timezone: zone)
        case .weekly:
            interval = 7
            if original != nil && !weeklyStartChanged {
                start = startDate
            } else {
                start = try RoutineSchedule.weeklyStartDate(weekday: weekday, timezone: timezone, now: now)
            }
        case .days:
            guard let number = Int(days), (1...365).contains(number) else { throw RoutineValidationError.days }
            interval = number
            start = startDate
        }
        guard RoutineSchedule.date(start) != nil else { throw RoutineValidationError.schedule }
        return RoutineValues(text: trimmed, intervalDays: interval, startDate: start,
                             localTime: String(format: "%02d:%02d:00", hour, minute), timezone: timezone)
    }
}

/// Dismissing a load error must not turn a failed read into an empty-state claim.
enum RoutinePresentation {
    static func showsEmpty(isLoading: Bool, hasLoaded: Bool, count: Int, loadFailed: Bool) -> Bool {
        !isLoading && hasLoaded && count == 0 && !loadFailed
    }
}
