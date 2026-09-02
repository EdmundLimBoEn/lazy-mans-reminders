import Foundation

/// Pulls the Supabase user id out of a GoTrue access token (`sub` in the JWT payload).
enum JWTUserID {
    static func uuid(fromAccessToken token: String) -> UUID? {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2,
              let data = decodeBase64URL(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String
        else {
            return nil
        }
        return UUID(uuidString: sub)
    }

    static func decodeBase64URL(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}

/// Fuzzy title match so Siri / Shortcuts can resolve “complete milk” without a UUID.
enum ReminderTitleMatcher {
    static func matches(_ reminders: [Reminder], query: String) -> [Reminder] {
        let active = reminders.filter { !$0.isDone }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return active }

        let scored: [(Reminder, Int)] = active.compactMap { reminder in
            let hay = reminder.text.lowercased()
            if hay == needle { return (reminder, 0) }
            if hay.contains(needle) { return (reminder, 1) }
            if needle.contains(hay), hay.count >= 3 { return (reminder, 2) }
            let words = hay.split { $0.isWhitespace || $0.isPunctuation }
            if words.contains(where: { $0.hasPrefix(needle) || (needle.hasPrefix($0) && $0.count >= 3) }) {
                return (reminder, 3)
            }
            return nil
        }
        return scored.sorted { $0.1 < $1.1 }.map(\.0)
    }
}

/// Spoken summary of the active board for Siri dialogs.
enum ReminderListSpoken {
    static func dialog(for reminders: [Reminder]) -> String {
        joinedTitles(reminders.filter { !$0.isDone }.map(\.text))
    }

    static func joinedTitles(_ titles: [String]) -> String {
        switch titles.count {
        case 0:
            return "Your board is empty."
        case 1:
            return "You have one reminder: \(titles[0])."
        case 2:
            return "You have two reminders: \(titles[0]) and \(titles[1])."
        default:
            let head = titles.dropLast().joined(separator: ", ")
            return "You have \(titles.count) reminders: \(head), and \(titles.last ?? "")."
        }
    }
}
