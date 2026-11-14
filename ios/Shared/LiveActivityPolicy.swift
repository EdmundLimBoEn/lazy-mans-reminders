import Foundation

enum LiveActivityPolicy {
    enum Action: Equatable {
        case none
        case end(EndReason)
        case update
        case start
    }

    enum EndReason: Equatable {
        case boardEmpty
        case clear

        /// ActivityKit owns dismissal, so suspension cannot leave an active empty board.
        func dismissalDate(now: Date) -> Date? {
            self == .boardEmpty ? now.addingTimeInterval(3) : nil
        }
    }

    static func selectedActivityID(
        currentIDs: [String], knownIDs: [String], previousSelection: String?
    ) -> String? {
        if let replacement = currentIDs.first(where: { !knownIDs.contains($0) }) {
            return replacement
        }
        if let previousSelection, currentIDs.contains(previousSelection) { return previousSelection }
        return currentIDs.first
    }

    /// Local reconciliation. Remote start/recycle lives on the server.
    static func action(lineCount: Int, activityExists: Bool, isClearing: Bool = false) -> Action {
        if isClearing {
            return activityExists ? .end(.clear) : .none
        }
        if lineCount == 0 {
            return activityExists ? .end(.boardEmpty) : .none
        }
        return activityExists ? .update : .start
    }
}
