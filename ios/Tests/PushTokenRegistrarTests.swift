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

    func testDeviceTokenChangeReregistersAcknowledgedActivityAndClock() async {
        var sent: [PushTokenRegistrar.Registration] = []
        let registrar = PushTokenRegistrar(defaults: defaults()) { sent.append($0) }
        let user = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        registrar.bind(userID: user)
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("activity", startedAt: startedAt)
        await registrar.flush()

        registrar.recordDeviceToken("changed-device")
        XCTAssertTrue(registrar.needsRetry)
        XCTAssertNil(registrar.lastSuccess)
        await registrar.flush()
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent.last?.token, "changed-device")
        XCTAssertEqual(sent.last?.userID, user)
        XCTAssertEqual(sent.last?.activityPushToken, "activity")
        XCTAssertEqual(sent.last?.activityStartedAt, "2027-01-15T08:00:00Z")
        XCTAssertFalse(registrar.needsRetry)

        registrar.recordDeviceToken("changed-device")
        registrar.recordActivityToken("activity", startedAt: startedAt)
        await registrar.flush()
        XCTAssertNil(sent.last?.activityPushToken)
        XCTAssertNil(sent.last?.activityStartedAt)
    }

    func testDeviceTokenChangePreservesNewerPendingActivityClock() async {
        var sent: [PushTokenRegistrar.Registration] = []
        let registrar = PushTokenRegistrar(defaults: defaults()) { sent.append($0) }
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        registrar.bind(userID: UUID())
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("old", startedAt: startedAt)
        await registrar.flush()

        // Even a token rotation for the same activity needs its clock on a new row.
        registrar.recordActivityToken("new", startedAt: startedAt)
        registrar.recordDeviceToken("changed-device")
        await registrar.flush()
        XCTAssertEqual(sent.last?.token, "changed-device")
        XCTAssertEqual(sent.last?.activityPushToken, "new")
        XCTAssertEqual(sent.last?.activityStartedAt, "2027-01-15T08:00:00Z")
    }

    func testDeviceTokenChangeSurvivesFailedUploadAndRelaunch() async {
        let storage = defaults()
        let user = UUID()
        let first = PushTokenRegistrar(defaults: storage, retryDelay: {}) {
            if $0.token == "changed-device" { throw URLError(.notConnectedToInternet) }
        }
        first.bind(userID: user)
        first.recordDeviceToken("device")
        first.recordActivityToken("activity", startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        await first.flush()
        first.recordDeviceToken("changed-device")
        await first.flush()
        XCTAssertTrue(first.needsRetry)

        var sent: [PushTokenRegistrar.Registration] = []
        let relaunched = PushTokenRegistrar(defaults: storage) { sent.append($0) }
        relaunched.bind(userID: user)
        XCTAssertTrue(relaunched.needsRetry)
        await relaunched.flush()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.token, "changed-device")
        XCTAssertEqual(sent.first?.activityPushToken, "activity")
        XCTAssertEqual(sent.first?.activityStartedAt, "2027-01-15T08:00:00Z")
    }

    func testDeviceTokenChangeDuringUploadCannotAcknowledgeTheNewDevice() async {
        var registrar: PushTokenRegistrar!
        var sent: [PushTokenRegistrar.Registration] = []
        registrar = PushTokenRegistrar(defaults: defaults()) { registration in
            sent.append(registration)
            if sent.count == 2 { registrar.recordDeviceToken("changed-device") }
        }
        registrar.bind(userID: UUID())
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("activity", startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        await registrar.flush()
        await registrar.flush()
        XCTAssertEqual(sent.count, 3)
        XCTAssertEqual(sent.last?.token, "changed-device")
        XCTAssertEqual(sent.last?.activityPushToken, "activity")
        XCTAssertEqual(sent.last?.activityStartedAt, "2027-01-15T08:00:00Z")
    }

    func testAccountSwitchDiscardsActivityRequeuedByDeviceTokenChange() async {
        var sent: [PushTokenRegistrar.Registration] = []
        let registrar = PushTokenRegistrar(defaults: defaults()) { sent.append($0) }
        registrar.bind(userID: UUID())
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("previous-account")
        await registrar.flush()
        registrar.recordDeviceToken("changed-device")
        let nextUser = UUID()
        registrar.bind(userID: nextUser)
        await registrar.flush()
        XCTAssertEqual(sent.last?.userID, nextUser)
        XCTAssertNil(sent.last?.activityPushToken)
        XCTAssertNil(sent.last?.activityStartedAt)
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

    func testLocallyRestoredActivityRegistersItsClockOnceAcrossTokenRotation() async throws {
        var sent: [PushTokenRegistrar.Registration] = []
        let registrar = PushTokenRegistrar(defaults: defaults()) { sent.append($0) }
        registrar.bind(userID: UUID())
        registrar.recordDeviceToken("device")
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        registrar.recordActivityToken("new-local", startedAt: startedAt)
        await registrar.flush()
        registrar.recordActivityToken("rotated", startedAt: startedAt)
        await registrar.flush()
        await registrar.flush()
        registrar.recordActivityToken("another-local", startedAt: startedAt.addingTimeInterval(3600))
        await registrar.flush()
        let encoded = try sent.map {
            try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as! [String: Any]
        }
        XCTAssertEqual(encoded[0]["activity_started_at"] as? String, "2027-01-15T08:00:00Z")
        XCTAssertNil(encoded[1]["activity_started_at"], "Rotation must preserve the server's current clock")
        XCTAssertNil(encoded[2]["activity_started_at"], "An acknowledged clock must not overwrite server handoff state")
        XCTAssertEqual(encoded[3]["activity_started_at"] as? String, "2027-01-15T09:00:00Z")
    }

    func testFailedRotationAndRelaunchCannotResetAnInFlightRenewalClock() async throws {
        let storage = defaults()
        let user = UUID()
        var renewing = false
        var serverClock = "old"
        let first = PushTokenRegistrar(defaults: storage, retryDelay: {}) { registration in
            if renewing { throw URLError(.notConnectedToInternet) }
            serverClock = registration.activityStartedAt ?? serverClock
        }
        first.bind(userID: user)
        first.recordDeviceToken("device")
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        first.recordActivityToken("original", startedAt: startedAt)
        await first.flush()
        XCTAssertEqual(serverClock, "2027-01-15T08:00:00Z")
        renewing = true
        serverClock = "replacement-requested"
        first.recordActivityToken("rotated-original", startedAt: startedAt)
        await first.flush()
        let relaunched = PushTokenRegistrar(defaults: storage) { registration in
            serverClock = registration.activityStartedAt ?? serverClock
        }
        relaunched.bind(userID: user)
        await relaunched.flush()
        XCTAssertEqual(serverClock, "replacement-requested")
    }

    func testRemoteActivityAcknowledgementKeepsTheServersStartClock() async throws {
        var encoded: [String: Any] = [:]
        let registrar = PushTokenRegistrar(defaults: defaults()) {
            encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as! [String: Any]
        }
        registrar.bind(userID: UUID())
        registrar.recordDeviceToken("device")
        registrar.recordActivityToken("remote")
        await registrar.flush()
        XCTAssertNil(encoded["activity_started_at"])
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
