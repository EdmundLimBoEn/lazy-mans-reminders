import XCTest
@testable import LazyMansReminders

@MainActor
final class PushTokenRegistrarTests: XCTestCase {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "PushTokenRegistrarTests-\(UUID().uuidString)")!
    }

    func testExpirationAndLateCompletionOnlyFinishBackgroundTaskOnce() {
        var completions: [Bool] = []
        let completion = BackgroundRefreshCompletion { completions.append($0) }
        completion.finish(success: false)
        completion.finish(success: true)
        XCTAssertEqual(completions, [false])
    }

    func testBackgroundRelaunchUploadsPendingActivityWithoutAViewOrNewDeviceCallback() async {
        let storage = defaults()
        let user = UUID()
        let first = PushTokenRegistrar(defaults: storage, retryDelay: {}) { _ in
            throw URLError(.notConnectedToInternet)
        }
        first.bind(userID: user)
        first.recordDeviceToken("device")
        first.recordPushToStartToken("start")
        first.recordActivityToken("replacement")
        await first.flush()
        XCTAssertTrue(first.needsRetry)

        var sent: [PushTokenRegistrar.Registration] = []
        let relaunched = PushTokenRegistrar(defaults: storage) { sent.append($0) }
        relaunched.bind(userID: user)
        await relaunched.flush()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.token, "device")
        XCTAssertEqual(sent.first?.activityPushToken, "replacement")
        XCTAssertFalse(relaunched.needsRetry)
        XCTAssertNotNil(relaunched.lastSuccess)
    }

    func testAcknowledgedTokenIsNotReplayedOverServerRenewalState() async throws {
        let storage = defaults()
        let user = UUID()
        let first = PushTokenRegistrar(defaults: storage) { _ in }
        first.bind(userID: user)
        first.recordDeviceToken("device")
        first.recordPushToStartToken("start")
        first.recordActivityToken("old")
        await first.flush()

        var encoded: [String: Any] = [:]
        let relaunched = PushTokenRegistrar(defaults: storage) { registration in
            encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(registration)) as! [String: Any]
        }
        relaunched.bind(userID: user)
        await relaunched.flush()
        XCTAssertNil(encoded["activity_push_token"])
        XCTAssertEqual(encoded["push_to_start_token"] as? String, "start")
        XCTAssertEqual(encoded["user_id"] as? String, user.uuidString)
    }

    func testCurrentTokenSnapshotIsNotReplayedAfterForegroundOrRelaunch() async {
        let storage = defaults()
        let user = UUID()
        var sent: [String?] = []
        let first = PushTokenRegistrar(defaults: storage) { sent.append($0.activityPushToken) }
        first.bind(userID: user)
        first.recordDeviceToken("device")
        first.recordActivityToken("old")
        await first.flush()
        first.recordActivityToken("old")
        await first.flush()

        let relaunched = PushTokenRegistrar(defaults: storage) { sent.append($0.activityPushToken) }
        relaunched.bind(userID: user)
        relaunched.recordActivityToken("old")
        await relaunched.flush()
        relaunched.recordActivityToken("replacement")
        await relaunched.flush()
        XCTAssertEqual(sent, ["old", nil, nil, "replacement"])
    }

    func testUnacknowledgedSnapshotRetriesWithoutANewTokenEvent() async {
        let storage = defaults()
        let user = UUID()
        let first = PushTokenRegistrar(defaults: storage, retryDelay: {}) { _ in
            throw URLError(.notConnectedToInternet)
        }
        first.bind(userID: user)
        first.recordDeviceToken("device")
        first.recordActivityToken("replacement")
        await first.flush()
        var sent: [String?] = []
        let relaunched = PushTokenRegistrar(defaults: storage) { sent.append($0.activityPushToken) }
        relaunched.bind(userID: user)
        relaunched.recordActivityToken("replacement")
        await relaunched.flush()
        XCTAssertEqual(sent, ["replacement"])
    }

    func testRepeatedSnapshotDuringUploadDoesNotCauseAnotherTokenUpload() async {
        var registrar: PushTokenRegistrar!
        var sent: [String?] = []
        registrar = PushTokenRegistrar(defaults: defaults()) { registration in
            sent.append(registration.activityPushToken)
            if sent.count == 1 { registrar.recordActivityToken("replacement") }
        }
        registrar.bind(userID: UUID())
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("replacement")
        await registrar.flush()
        XCTAssertEqual(sent, ["replacement"])
    }

    func testNewTokenArrivingDuringUploadIsNotAcknowledgedByOldResponse() async {
        var registrar: PushTokenRegistrar!
        var sent: [String?] = []
        registrar = PushTokenRegistrar(defaults: defaults()) { registration in
            sent.append(registration.activityPushToken)
            if sent.count == 1 { registrar.recordActivityToken("new") }
        }
        registrar.bind(userID: UUID())
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("old")
        await registrar.flush()
        XCTAssertEqual(sent, ["old", "new"])
    }

    func testTokenBeforeInitialSessionRestorationIsRetained() async {
        var sent: [String?] = []
        let registrar = PushTokenRegistrar(defaults: defaults()) { sent.append($0.activityPushToken) }
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("new")
        await registrar.flush()
        XCTAssertTrue(sent.isEmpty)
        registrar.bind(userID: UUID())
        await registrar.flush()
        XCTAssertEqual(sent, ["new"])
    }

    func testAccountSwitchDoesNotAttachPreviousUsersActivity() async {
        var sent: [PushTokenRegistrar.Registration] = []
        let registrar = PushTokenRegistrar(defaults: defaults()) { sent.append($0) }
        registrar.bind(userID: UUID())
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("private-old-board")
        registrar.bind(userID: nil)
        registrar.recordActivityToken("late-old-board")
        await registrar.flush()
        XCTAssertTrue(sent.isEmpty)
        let nextUser = UUID()
        registrar.bind(userID: nextUser)
        await registrar.flush()
        XCTAssertEqual(sent.first?.userID, nextUser)
        XCTAssertNil(sent.first?.activityPushToken)
    }
}
