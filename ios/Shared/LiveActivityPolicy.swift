import Foundation

enum LiveActivityPolicy {
    enum Action: Equatable {
        case none
        case end
        case update
        case start
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
    static func action(lineCount: Int, activityExists: Bool) -> Action {
        if lineCount == 0 {
            return activityExists ? .end : .none
        }
        return activityExists ? .update : .start
    }
}
