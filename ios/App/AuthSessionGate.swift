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

    /// Caller holds the gate. Authenticate only after the old credential has removed
    /// its registration; the SDK may persist a replacement before returning.
    func authenticate<T>(pauseRegistration: () async -> Void,
                         resumeRegistration: () -> Void,
                         removeDeviceToken: () async throws -> Void,
                         operation: () async throws -> T) async throws -> T {
        precondition(isHeld)
        await pauseRegistration()
        defer { resumeRegistration() }
        try await removeDeviceToken()
        return try await operation()
    }

    struct DeviceTokenRow: Decodable {
        let token: String
    }

    enum DeregistrationError: LocalizedError {
        case unconfirmed

        var errorDescription: String? {
            "Couldn’t confirm device removal. Reconnect and try again before switching accounts or signing out."
        }
    }

    static func verifyAbsence(_ rows: [DeviceTokenRow]) throws {
        guard rows.isEmpty else {
            throw DeregistrationError.unconfirmed
        }
    }

    struct CleanupOperations {
        let setEndingSession: (Bool) -> Void
        let pauseRegistration: () async -> Void
        let resumeRegistration: () -> Void
        let unbind: () async -> Void
        let removeDeviceToken: () async throws -> Void
        let signOutSDK: () async -> Void
        let clearPublishedSession: () -> Void
        let clearUserData: () async -> Void
        let clearBoard: () async -> Void
    }

    enum CleanupReason {
        case voluntarySignOut
        case verifiedRevocation
    }

    @discardableResult
    func cleanUp(reason: CleanupReason = .voluntarySignOut, if shouldProceed: () -> Bool = { true },
                 operations: CleanupOperations) async -> Bool {
        await withLock {
            guard shouldProceed() else { return false }
            operations.setEndingSession(true)
            defer { operations.setEndingSession(false) }
            await operations.pauseRegistration()
            defer { operations.resumeRegistration() }
            do {
                try await operations.removeDeviceToken()
            } catch {
                // Voluntary sign-out can retry with the intact session and registrar.
                // Verified revocation must clear local account data even when offline.
                if reason == .voluntarySignOut { return false }
            }
            await operations.unbind()
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
