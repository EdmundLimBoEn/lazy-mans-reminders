import XCTest
@testable import LazyMansReminders

@MainActor
final class AuthSessionGateTests: XCTestCase {
    func testIdentityReplacementWaitsForCleanupBeforeSharing() async {
        let gate = AuthSessionGate()
        let clearing = Signal()
        let finishClear = Signal()
        var steps: [String] = []
        let replacement = Task {
            await gate.withLock {
                await gate.shareIdentity(
                    previousUserID: UUID(), nextUserID: UUID(),
                    clearUserData: { steps.append("invalidate") },
                    clearBoard: {
                        clearing.send()
                        await finishClear.wait()
                        steps.append("clear")
                    },
                    share: { steps.append("share") }
                )
            }
        }
        await clearing.wait()
        XCTAssertEqual(steps, ["invalidate"])
        // SDK replacement already succeeded: cancellation must not skip cleanup.
        replacement.cancel()
        finishClear.send()
        await replacement.value
        XCTAssertEqual(steps, ["invalidate", "clear", "share"])
    }

    func testSharingSameIdentityPreservesOfflineBoard() async {
        let gate = AuthSessionGate()
        let account = UUID()
        var shared = false
        await gate.withLock {
            await gate.shareIdentity(
                previousUserID: account, nextUserID: account,
                clearUserData: { XCTFail("Same-account refresh must retain its cache") },
                clearBoard: { XCTFail("Same-account refresh must retain published reminders") },
                share: { shared = true }
            )
        }
        XCTAssertTrue(shared)
    }

    func testAccountSwitchRequiresVerifiedRemovalWithPreviousCredentials() async throws {
        let gate = AuthSessionGate()
        let suite = "AccountSwitchTests-\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let accountA = UUID()
        let accountB = UUID()
        var sdkAccount = accountA
        var publishedAccount = accountA
        var registeredOwner: UUID? = accountA
        var uploads: [UUID] = []
        let registrar = PushTokenRegistrar(defaults: storage) { registration in
            uploads.append(registration.userID)
            registeredOwner = registration.userID
        }
        registrar.bind(userID: accountA)
        registrar.recordDeviceToken("device")
        var rows: [AuthSessionGate.DeviceTokenRow] = [.init(token: "device")]
        var networkFailure = true
        var replacements = 0
        let attempt = {
            try await gate.withLock {
                let next = try await gate.authenticate(
                    pauseRegistration: { await registrar.pause() },
                    resumeRegistration: { registrar.resume() },
                    removeDeviceToken: {
                        XCTAssertEqual(sdkAccount, accountA, "Use A's credentials before the SDK persists B")
                        await registrar.flush()
                        XCTAssertTrue(uploads.isEmpty, "Uploads must not recreate A's row during removal")
                        if networkFailure { throw URLError(.notConnectedToInternet) }
                        try AuthSessionGate.verifyAbsence(rows)
                        registeredOwner = nil
                    },
                    operation: {
                        XCTAssertNil(registeredOwner)
                        replacements += 1
                        sdkAccount = accountB
                        return accountB
                    }
                )
                publishedAccount = next
                registrar.bind(userID: next)
                await registrar.flush()
            }
        }

        // Both a transport failure and a row remaining after deletion must
        // leave A installed and prevent callback completion.
        for offline in [true, false] {
            networkFailure = offline
            do {
                try await attempt()
                XCTFail("Unconfirmed removal must reject the switch")
            } catch { }
            XCTAssertEqual(sdkAccount, accountA)
            XCTAssertEqual(publishedAccount, accountA)
            XCTAssertEqual(registeredOwner, accountA)
            XCTAssertEqual(replacements, 0)
            XCTAssertEqual(registrar.deviceToken, "device")
        }
        rows = []
        try await attempt()
        XCTAssertEqual(replacements, 1)
        XCTAssertEqual(sdkAccount, accountB)
        XCTAssertEqual(publishedAccount, accountB)
        XCTAssertEqual(registeredOwner, accountB)
        XCTAssertEqual(uploads, [accountB])
    }

    func testFailedAuthenticationResumesOldRegistrationAndReleasesGate() async {
        let gate = AuthSessionGate()
        var paused = false
        var removed = false
        do {
            try await gate.withLock {
                try await gate.authenticate(
                    pauseRegistration: { paused = true },
                    resumeRegistration: { paused = false },
                    removeDeviceToken: { removed = true },
                    operation: { () async throws -> Void in
                        XCTAssertTrue(paused)
                        XCTAssertTrue(removed)
                        throw URLError(.userAuthenticationRequired)
                    }
                )
            }
            XCTFail("Expected authentication failure")
        } catch { }
        XCTAssertFalse(paused)
        await gate.withLock { XCTAssertTrue(removed) }
    }

    func testAuthenticationRestoresAcknowledgedActivityOnlyForOriginalAccount() async throws {
        for outcome in ["failure", "cancel", "same", "switch"] {
            for rotated in [false, true] {
                let suite = "AuthRestorationTests-\(UUID().uuidString)"
                let storage = UserDefaults(suiteName: suite)!
                defer { storage.removePersistentDomain(forName: suite) }
                let oldUser = UUID()
                let nextUser = outcome == "switch" ? UUID() : oldUser
                var sent: [PushTokenRegistrar.Registration] = []
                let registrar = PushTokenRegistrar(defaults: storage) { sent.append($0) }
                registrar.bind(userID: oldUser)
                registrar.recordDeviceToken("device")
                registrar.recordPushToStartToken("start")
                registrar.recordActivityToken("acknowledged", startedAt: Date(timeIntervalSince1970: 1_800_000_000))
                await registrar.flush()
                XCTAssertEqual(sent.count, 1)
                let gate = AuthSessionGate()
                await gate.withLock {
                    do {
                        let user = try await gate.authenticate(
                            pauseRegistration: { await registrar.pause() },
                            resumeRegistration: { registrar.resume() },
                            removeDeviceToken: {
                                if rotated {
                                    registrar.recordActivityToken("rotated", startedAt: Date(timeIntervalSince1970: 1_800_000_000))
                                }
                                registrar.registrationWasRemoved()
                                await registrar.flush()
                                XCTAssertEqual(sent.count, 1, "Restoration must wait for authentication")
                            },
                            operation: {
                                if outcome == "failure" { throw URLError(.userAuthenticationRequired) }
                                if outcome == "cancel" { throw CancellationError() }
                                return nextUser
                            }
                        )
                        registrar.bind(userID: user)
                    } catch {
                        XCTAssertTrue(outcome == "failure" || outcome == "cancel")
                    }
                    await registrar.flush()
                }
                XCTAssertEqual(sent.count, 2)
                XCTAssertEqual(sent.last?.userID, nextUser)
                XCTAssertEqual(sent.last?.pushToStartToken, "start")
                XCTAssertEqual(sent.last?.activityPushToken,
                               outcome == "switch" ? nil : (rotated ? "rotated" : "acknowledged"))
                XCTAssertEqual(sent.last?.activityStartedAt,
                               outcome == "switch" ? nil : "2027-01-15T08:00:00Z")
                await registrar.flush()
                XCTAssertNil(sent.last?.activityPushToken, "Restoration should only replay once")
            }
        }
    }

    func testRemovedRegistrationRestorationSurvivesRelaunch() async {
        let suite = "AuthRestorationRetryTests-\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let user = UUID()
        let registrar = PushTokenRegistrar(defaults: storage) { _ in }
        registrar.bind(userID: user)
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("acknowledged", startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        await registrar.flush()
        await registrar.pause()
        registrar.registrationWasRemoved()
        // A cancelled authentication task may not be able to upload immediately.
        let offline = PushTokenRegistrar(defaults: storage, retryDelay: {}) { _ in
            throw URLError(.notConnectedToInternet)
        }
        await offline.flush()
        XCTAssertTrue(offline.needsRetry)
        var sent: [PushTokenRegistrar.Registration] = []
        let relaunched = PushTokenRegistrar(defaults: storage) { sent.append($0) }
        relaunched.bind(userID: user)
        await relaunched.flush()
        XCTAssertEqual(sent.first?.activityPushToken, "acknowledged")
        XCTAssertEqual(sent.first?.activityStartedAt, "2027-01-15T08:00:00Z")
        XCTAssertFalse(relaunched.needsRetry)
    }

    func testDeletionVerificationRequiresAbsence() throws {
        try AuthSessionGate.verifyAbsence([])
        XCTAssertThrowsError(try AuthSessionGate.verifyAbsence([.init(token: "device")]))
    }

    func testSignOutRetriesAfterLostDeletionResponseOrMissingRegistration() async {
        for initiallyRegistered in [true, false] {
            let gate = AuthSessionGate()
            var registered = initiallyRegistered
            var loseResponse = initiallyRegistered
            var signedOut = false
            let operations = AuthSessionGate.CleanupOperations(
                setEndingSession: { _ in }, pauseRegistration: {}, resumeRegistration: {}, unbind: {},
                removeDeviceToken: {
                    registered = false
                    if loseResponse { throw URLError(.networkConnectionLost) }
                    try AuthSessionGate.verifyAbsence(registered ? [.init(token: "device")] : [])
                },
                signOutSDK: { signedOut = true },
                clearPublishedSession: {}, clearUserData: {}, clearBoard: {}
            )
            if initiallyRegistered {
                let result = await gate.cleanUp(operations: operations)
                XCTAssertFalse(result)
                XCTAssertFalse(signedOut)
                XCTAssertFalse(registered)
            }
            loseResponse = false
            let result = await gate.cleanUp(operations: operations)
            XCTAssertTrue(result)
            XCTAssertTrue(signedOut)
        }
    }

    func testAbortedSignOutPreservesPendingTokensAndAcceptsUpdatesDuringDeletion() async {
        for rotatesDuringDeletion in [false, true] {
            let suite = "SignOutRegistrationTests-\(UUID().uuidString)"
            let storage = UserDefaults(suiteName: suite)!
            defer { storage.removePersistentDomain(forName: suite) }
            var sent: [PushTokenRegistrar.Registration] = []
            let registrar = PushTokenRegistrar(defaults: storage) { sent.append($0) }
            let user = UUID()
            let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
            registrar.bind(userID: user)
            registrar.recordDeviceToken("device")
            registrar.recordPushToStartToken("start")
            registrar.recordActivityToken("pending", startedAt: startedAt)
            let result = await AuthSessionGate().cleanUp(operations: .init(
                setEndingSession: { _ in },
                pauseRegistration: { await registrar.pause() },
                resumeRegistration: { registrar.resume() },
                unbind: { await registrar.unbind() },
                removeDeviceToken: {
                    if rotatesDuringDeletion {
                        registrar.recordActivityToken("rotated", startedAt: startedAt)
                    }
                    await registrar.flush()
                    XCTAssertTrue(sent.isEmpty, "Uploads must stay paused until deletion finishes")
                    throw URLError(.notConnectedToInternet)
                },
                signOutSDK: { XCTFail("Aborted sign-out must keep the session") },
                clearPublishedSession: {}, clearUserData: {}, clearBoard: {}
            ))
            XCTAssertFalse(result)
            XCTAssertTrue(registrar.needsRetry)
            await registrar.flush()
            XCTAssertEqual(sent.count, 1)
            XCTAssertEqual(sent.first?.userID, user)
            XCTAssertEqual(sent.first?.pushToStartToken, "start")
            XCTAssertEqual(sent.first?.activityPushToken, rotatesDuringDeletion ? "rotated" : "pending")
            XCTAssertEqual(sent.first?.activityStartedAt, "2027-01-15T08:00:00Z")
            registrar.recordActivityToken("next")
            await registrar.flush()
            XCTAssertEqual(sent.last?.activityPushToken, "next")
        }
    }

    func testPauseDrainsInFlightUploadAndRetainsNewActivityToken() async {
        let suite = "SignOutDrainTests-\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let uploadStarted = Signal()
        let finishUpload = Signal()
        let pauseStarted = Signal()
        var sent: [String?] = []
        let registrar = PushTokenRegistrar(defaults: storage) { registration in
            sent.append(registration.activityPushToken)
            if sent.count == 1 {
                uploadStarted.send()
                await finishUpload.wait()
            }
        }
        registrar.bind(userID: UUID())
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("old")
        let upload = Task { await registrar.flush() }
        await uploadStarted.wait()
        var drained = false
        let pause = Task {
            pauseStarted.send()
            await registrar.pause()
            drained = true
        }
        await pauseStarted.wait()
        XCTAssertFalse(drained)
        registrar.recordActivityToken("new")
        finishUpload.send()
        await upload.value
        await pause.value
        XCTAssertTrue(drained)
        XCTAssertEqual(sent, ["old"])
        await registrar.flush()
        XCTAssertEqual(sent, ["old"])
        registrar.resume()
        await registrar.flush()
        XCTAssertEqual(sent, ["old", "new"])
    }

    func testVerifiedRevocationClearsLocalStateDespiteDeregistrationFailure() async {
        let failures: [Error] = [URLError(.notConnectedToInternet), CancellationError()]
        for failure in failures {
            var steps: [String] = []
            var isEnding = false
            let result = await AuthSessionGate().cleanUp(reason: .verifiedRevocation, operations: .init(
                setEndingSession: { isEnding = $0 },
                pauseRegistration: { steps.append("pause") },
                resumeRegistration: { steps.append("resume") },
                unbind: { steps.append("unbind") },
                removeDeviceToken: { steps.append("delete"); throw failure },
                signOutSDK: { steps.append("sign-out") },
                clearPublishedSession: { steps.append("session") },
                clearUserData: { steps.append("cache") },
                clearBoard: { steps.append("board") }
            ))
            XCTAssertTrue(result)
            XCTAssertFalse(isEnding)
            XCTAssertEqual(steps, ["pause", "delete", "unbind", "sign-out", "session", "cache", "board", "resume"])
        }
    }

    func testFailedDeregistrationKeepsDeviceTokenAcrossRelaunchForRetry() async {
        let suite = "SignOutRetryTests-\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let registrar = PushTokenRegistrar(defaults: storage) { _ in }
        registrar.bind(userID: UUID())
        registrar.recordDeviceToken("device-A")
        let gate = AuthSessionGate()
        var retainedSession = true
        let failed = await gate.cleanUp(operations: .init(
            setEndingSession: { _ in },
            pauseRegistration: { await registrar.pause() },
            resumeRegistration: { registrar.resume() },
            unbind: { await registrar.unbind() },
            removeDeviceToken: { throw URLError(.notConnectedToInternet) },
            signOutSDK: { retainedSession = false },
            clearPublishedSession: {}, clearUserData: {}, clearBoard: {}
        ))
        XCTAssertFalse(failed)

        let relaunched = PushTokenRegistrar(defaults: storage) { _ in }
        var deletedToken: String?
        let retried = await AuthSessionGate().cleanUp(operations: .init(
            setEndingSession: { _ in },
            pauseRegistration: { await relaunched.pause() },
            resumeRegistration: { relaunched.resume() },
            unbind: { await relaunched.unbind() },
            removeDeviceToken: {
                XCTAssertTrue(retainedSession)
                deletedToken = relaunched.deviceToken
            },
            signOutSDK: { retainedSession = false },
            clearPublishedSession: {}, clearUserData: {}, clearBoard: {}
        ))
        XCTAssertTrue(retried)
        XCTAssertEqual(deletedToken, "device-A")
        XCTAssertFalse(retainedSession)
    }

    func testFailedDeregistrationPreservesSessionUntilRetrySucceeds() async {
        enum Failure: Error { case offline }
        let failures: [Error] = [Failure.offline, CancellationError()]
        for failure in failures {
            let gate = AuthSessionGate()
            var deleteFailure: Error? = failure
            var isEnding = false
            var authenticated = true
            var published = true
            var cachePresent = true
            var boardPresent = true
            var remotelyRegistered = true
            var steps: [String] = []
            let operations = AuthSessionGate.CleanupOperations(
                setEndingSession: { isEnding = $0 },
                pauseRegistration: { steps.append("pause") },
                resumeRegistration: { steps.append("resume") },
                unbind: { steps.append("unbind") },
                removeDeviceToken: {
                    XCTAssertTrue(authenticated, "Deletion must retain its authentication context")
                    steps.append("delete")
                    if let deleteFailure { throw deleteFailure }
                    remotelyRegistered = false
                },
                signOutSDK: {
                    XCTAssertFalse(remotelyRegistered)
                    authenticated = false
                    steps.append("sign-out")
                },
                clearPublishedSession: { published = false },
                clearUserData: { cachePresent = false },
                clearBoard: { boardPresent = false }
            )

            let failed = await gate.cleanUp(operations: operations)
            XCTAssertFalse(failed)
            XCTAssertTrue(authenticated)
            XCTAssertTrue(published)
            XCTAssertTrue(cachePresent)
            XCTAssertTrue(boardPresent)
            XCTAssertTrue(remotelyRegistered)
            XCTAssertFalse(isEnding)
            XCTAssertEqual(steps, ["pause", "delete", "resume"])

            deleteFailure = nil
            let retried = await gate.cleanUp(operations: operations)
            XCTAssertTrue(retried)
            XCTAssertFalse(authenticated)
            XCTAssertFalse(published)
            XCTAssertFalse(cachePresent)
            XCTAssertFalse(boardPresent)
            XCTAssertFalse(remotelyRegistered)
            XCTAssertFalse(isEnding)
            XCTAssertEqual(steps, ["pause", "delete", "resume", "pause", "delete", "unbind", "sign-out", "resume"])
        }
    }

    @MainActor
    private final class Signal {
        private var arrived = false
        private var waiter: CheckedContinuation<Void, Never>?

        func wait() async {
            if arrived { return }
            await withCheckedContinuation { waiter = $0 }
        }

        func send() {
            arrived = true
            waiter?.resume()
            waiter = nil
        }
    }

    func testCallbackBInstallsOnlyAfterSuspendedCleanupCompletes() async {
        // Exercise the production gate with injected SDK and cache operations.
        // Both ordinary and revocation sign-out use the same gated cleanup path.
        for revocation in [false, true] {
            for suspendedStage in ["pause", "unbind", "token-delete", "sdk-sign-out", "cache-clear", "widget-clear"] {
                let gate = AuthSessionGate()
                let cleanupSuspended = Signal()
                let resumeCleanup = Signal()
                let callbackSubmitted = Signal()
                var sdkAccount: String? = "A"
                var publishedAccount: String? = "A"
                var cacheAccount: String? = "A"
                var widgetAccount: String? = "A"
                var operations: [String] = []
                var isEnding = false
                let step: (String) async -> Void = { stage in
                    if stage == suspendedStage {
                        cleanupSuspended.send()
                        await resumeCleanup.wait()
                    }
                    operations.append(stage)
                }
                let cleanupOperations = AuthSessionGate.CleanupOperations(
                    setEndingSession: { isEnding = $0 },
                    pauseRegistration: { await step("pause") },
                    resumeRegistration: {},
                    unbind: { await step("unbind") },
                    removeDeviceToken: { await step("token-delete") },
                    signOutSDK: { await step("sdk-sign-out"); sdkAccount = nil },
                    clearPublishedSession: { publishedAccount = nil },
                    clearUserData: { await step("cache-clear"); cacheAccount = nil },
                    clearBoard: { await step("widget-clear"); widgetAccount = nil }
                )
                let cleanup = Task {
                    if revocation {
                        return await gate.cleanUp(reason: .verifiedRevocation, if: { true }, operations: cleanupOperations)
                    }
                    return await gate.cleanUp(operations: cleanupOperations)
                }
                await cleanupSuspended.wait()
                let callback = Task {
                    callbackSubmitted.send()
                    await gate.withLock {
                        // Represents auth.session(from: url) followed by session/cache sharing.
                        sdkAccount = "B"
                        publishedAccount = "B"
                        operations.append("sdk-install-B")
                        cacheAccount = "B"
                        widgetAccount = "B"
                        operations.append("share-B")
                    }
                }
                await callbackSubmitted.wait()
                XCTAssertTrue(isEnding)
                XCTAssertFalse(operations.contains("sdk-install-B"), suspendedStage)
                resumeCleanup.send()
                await cleanup.value
                await callback.value
                XCTAssertEqual(operations, ["pause", "token-delete", "unbind", "sdk-sign-out", "cache-clear",
                                             "widget-clear", "sdk-install-B", "share-B"])
                XCTAssertEqual(sdkAccount, "B")
                XCTAssertEqual(publishedAccount, "B")
                XCTAssertEqual(cacheAccount, "B")
                XCTAssertEqual(widgetAccount, "B")
                XCTAssertFalse(isEnding)
            }
        }
    }

    func testRevocationChecksIdentityAfterAcquiringCleanupGate() async {
        let gate = AuthSessionGate()
        await gate.acquire()
        var currentAccount = "A"
        var cleared = false
        let submitted = Signal()
        let operations = AuthSessionGate.CleanupOperations(
            setEndingSession: { _ in }, pauseRegistration: {}, resumeRegistration: {}, unbind: {}, removeDeviceToken: {}, signOutSDK: {},
            clearPublishedSession: { cleared = true }, clearUserData: {}, clearBoard: {}
        )
        let revokedA = Task {
            submitted.send()
            return await gate.cleanUp(reason: .verifiedRevocation, if: { currentAccount == "A" }, operations: operations)
        }
        await submitted.wait()
        currentAccount = "B"
        gate.release()
        let didClean = await revokedA.value
        XCTAssertFalse(didClean)
        XCTAssertFalse(cleared)
        XCTAssertEqual(currentAccount, "B")
    }

    func testSuspendedSDKRefreshFinishesBeforeCleanupAndCallbackB() async {
        let gate = AuthSessionGate()
        let refreshStarted = Signal()
        let finishRefresh = Signal()
        let cleanupSubmitted = Signal()
        let callbackSubmitted = Signal()
        var sdkAccount: String? = "A"
        var cacheAccount: String? = "A"
        var order: [String] = []
        let refreshA = Task {
            await gate.withLock {
                refreshStarted.send()
                await finishRefresh.wait()
                sdkAccount = "A"
                order.append("refresh-A")
            }
        }
        await refreshStarted.wait()
        let operations = AuthSessionGate.CleanupOperations(
            setEndingSession: { _ in }, pauseRegistration: {}, resumeRegistration: {}, unbind: {}, removeDeviceToken: {},
            signOutSDK: { sdkAccount = nil; order.append("sign-out-A") },
            clearPublishedSession: {}, clearUserData: { cacheAccount = nil }, clearBoard: {}
        )
        let cleanup = Task {
            cleanupSubmitted.send()
            await gate.cleanUp(operations: operations)
        }
        await cleanupSubmitted.wait()
        let callbackB = Task {
            callbackSubmitted.send()
            await gate.withLock {
                sdkAccount = "B"
                cacheAccount = "B"
                order.append("install-B")
            }
        }
        await callbackSubmitted.wait()
        XCTAssertTrue(order.isEmpty)
        finishRefresh.send()
        await refreshA.value
        await cleanup.value
        await callbackB.value
        XCTAssertEqual(order, ["refresh-A", "sign-out-A", "install-B"])
        XCTAssertEqual(sdkAccount, "B")
        XCTAssertEqual(cacheAccount, "B")
    }

    func testQueuedSignedOutEventDoesNotClearCompletedCallbackB() async {
        let gate = AuthSessionGate()
        let accountB = UUID()
        let callbackStarted = Signal()
        let resumeCallback = Signal()
        let eventSubmitted = Signal()
        var sdkAccount: UUID?
        var sdkToken: String?
        var cacheAccount: UUID?
        let callback = Task {
            await gate.withLock {
                sdkAccount = accountB
                sdkToken = "B-token"
                callbackStarted.send()
                await resumeCallback.wait()
                cacheAccount = accountB
            }
        }
        await callbackStarted.wait()
        let oldSignedOutEvent = Task {
            eventSubmitted.send()
            await gate.withLock {
                guard AuthSessionGate.matchesEvent(eventUserID: nil, eventAccessToken: nil,
                                                   currentUserID: sdkAccount, currentAccessToken: sdkToken)
                else { return }
                cacheAccount = nil
            }
        }
        await eventSubmitted.wait()
        resumeCallback.send()
        await callback.value
        await oldSignedOutEvent.value
        XCTAssertEqual(sdkAccount, accountB)
        XCTAssertEqual(cacheAccount, accountB)
    }

    func testCancelledWaiterReleasesGateBeforeNextValidCallback() async {
        let gate = AuthSessionGate()
        await gate.acquire()
        let submitted = Signal()
        var cancelledOperationRan = false
        let cancelled = Task {
            submitted.send()
            await gate.acquire()
            defer { gate.release() }
            guard !Task.isCancelled else { return }
            cancelledOperationRan = true
        }
        await submitted.wait()
        cancelled.cancel()
        gate.release()
        await cancelled.value
        var validCallbackRan = false
        await gate.withLock { validCallbackRan = true }
        XCTAssertFalse(cancelledOperationRan)
        XCTAssertTrue(validCallbackRan)
    }

    func testThrowingReplacementReleasesGateForRecovery() async {
        let gate = AuthSessionGate()
        enum Failure: Error { case invalidCallback }
        do {
            try await gate.withLock { throw Failure.invalidCallback }
            XCTFail("Expected invalid callback")
        } catch { }
        var recovered = false
        await gate.withLock { recovered = true }
        XCTAssertTrue(recovered)
    }

    func testCurrentEventAcceptedAndStaleTokenRefreshSkipped() {
        let user = UUID()
        XCTAssertTrue(AuthSessionGate.matchesEvent(eventUserID: user, eventAccessToken: "new",
                                                   currentUserID: user, currentAccessToken: "new"))
        XCTAssertFalse(AuthSessionGate.matchesEvent(eventUserID: user, eventAccessToken: "old",
                                                    currentUserID: user, currentAccessToken: "new"))
        XCTAssertTrue(AuthSessionGate.matchesEvent(eventUserID: nil, eventAccessToken: nil,
                                                   currentUserID: nil, currentAccessToken: nil))
    }
}
