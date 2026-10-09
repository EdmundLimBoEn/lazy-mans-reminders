import Foundation

/// Serializes SDK session replacement with local cleanup across suspension points.
@MainActor
final class AuthSessionGate {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    // Cancellation leaves the caller queued. It must release after acquiring,
    // even when its operation then returns early because it was cancelled.
    func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        precondition(isHeld)
        if waiters.isEmpty {
            isHeld = false
        } else {
            // Ownership passes directly to the waiter; a new caller cannot overtake it.
            waiters.removeFirst().resume()
        }
    }

    func withLock<T>(_ operation: () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }

    struct CleanupOperations {
        let setEndingSession: (Bool) -> Void
        let unbind: () async -> Void
        let removeDeviceToken: () async -> Void
        let signOutSDK: () async -> Void
        let clearPublishedSession: () -> Void
        let clearUserData: () async -> Void
        let clearBoard: () async -> Void
    }

    @discardableResult
    func cleanUp(if shouldProceed: () -> Bool = { true },
                 operations: CleanupOperations) async -> Bool {
        await withLock {
            guard shouldProceed() else { return false }
            operations.setEndingSession(true)
            defer { operations.setEndingSession(false) }
            await operations.unbind()
            await operations.removeDeviceToken()
            await operations.signOutSDK()
            operations.clearPublishedSession()
            await operations.clearUserData()
            await operations.clearBoard()
            return true
        }
    }

    static func matchesEvent(eventUserID: UUID?, eventAccessToken: String?,
                             currentUserID: UUID?, currentAccessToken: String?) -> Bool {
        eventUserID == currentUserID && eventAccessToken == currentAccessToken
    }
}
