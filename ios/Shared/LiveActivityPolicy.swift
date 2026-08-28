import Foundation

enum LiveActivityPolicy {
    enum Action: Equatable {
        case none
        case end
        case update
        case start
    }

    /// Local reconciliation. Remote start/recycle lives on the server.
    static func action(lineCount: Int, activityExists: Bool) -> Action {
        if lineCount == 0 {
            return activityExists ? .end : .none
        }
        return activityExists ? .update : .start
    }
}
