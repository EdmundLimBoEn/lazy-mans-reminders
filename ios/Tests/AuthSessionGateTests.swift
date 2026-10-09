import XCTest
@testable import LazyMansReminders

@MainActor
final class AuthSessionGateTests: XCTestCase {
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
            for suspendedStage in ["unbind", "token-delete", "sdk-sign-out", "cache-clear", "widget-clear"] {
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
                    unbind: { await step("unbind") },
                    removeDeviceToken: { await step("token-delete") },
                    signOutSDK: { await step("sdk-sign-out"); sdkAccount = nil },
                    clearPublishedSession: { publishedAccount = nil },
                    clearUserData: { await step("cache-clear"); cacheAccount = nil },
                    clearBoard: { await step("widget-clear"); widgetAccount = nil }
                )
                let cleanup = Task {
                    if revocation {
                        return await gate.cleanUp(if: { true }, operations: cleanupOperations)
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
                XCTAssertEqual(operations, ["unbind", "token-delete", "sdk-sign-out", "cache-clear",
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
            setEndingSession: { _ in }, unbind: {}, removeDeviceToken: {}, signOutSDK: {},
            clearPublishedSession: { cleared = true }, clearUserData: {}, clearBoard: {}
        )
        let revokedA = Task {
            submitted.send()
            return await gate.cleanUp(if: { currentAccount == "A" }, operations: operations)
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
            setEndingSession: { _ in }, unbind: {}, removeDeviceToken: {},
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
