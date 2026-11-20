#if DEBUG
import Foundation

@MainActor
final class MacDemoBoard: MacBoardBackend {
    enum State {
        case signedOut
        case board
        case full
    }

    private let userID = UUID()
    private(set) var hasSession: Bool
    private(set) var reminders: [Reminder] = []

    init(_ state: State) {
        hasSession = state != .signedOut
        let examples = [
            "Water the plants", "Pick up the library books", "Book a dentist appointment",
            "Pay the electricity bill", "Call Dad", "Send the invoice", "Refill the printer",
            "Replace the bike light", "Buy stamps", "Mend the blue jacket",
            "Return the spare keys", "Order cat food", "Wash the car", "Check the flight time",
            "Write a thank-you card", "Book a haircut"
        ]
        let count = switch state {
        case .signedOut: 0
        case .board: 4
        case .full: ReminderBoardLimits.maxActive
        }
        for text in examples.prefix(count) {
            append(text)
        }
    }

    func refresh(performMaintenance: Bool) async throws -> [Reminder] { reminders }

    func add(_ text: String) async throws -> [Reminder] {
        append(text)
        return reminders
    }

    func complete(_ id: UUID) async throws -> [Reminder] {
        reminders.removeAll { $0.id == id }
        return reminders
    }

    func signOut() async {
        reminders = []
        hasSession = false
    }

    private func append(_ text: String) {
        reminders.append(Reminder(
            id: UUID(), userID: userID, text: text,
            sortOrder: (reminders.last?.sortOrder ?? -1) + 1,
            isDone: false, createdAt: Date()
        ))
    }
}
#endif
