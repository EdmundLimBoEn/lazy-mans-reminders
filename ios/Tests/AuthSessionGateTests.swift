import XCTest
@testable import LazyMansReminders

@MainActor
final class AuthSessionGateTests: XCTestCase {
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
