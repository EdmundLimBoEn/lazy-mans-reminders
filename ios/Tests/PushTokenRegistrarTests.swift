import XCTest
@testable import LazyMansReminders

@MainActor
final class PushTokenRegistrarTests: XCTestCase {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "PushTokenRegistrarTests-\(UUID().uuidString)")!
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
        first.recordActivityToken("old")
        await first.flush()

        var encoded: [String: Any] = [:]
        let relaunched = PushTokenRegistrar(defaults: storage) { registration in
            encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(registration)) as! [String: Any]
        }
        relaunched.bind(userID: user)
        await relaunched.flush()
        XCTAssertNil(encoded["activity_push_token"])
        XCTAssertEqual(encoded["user_id"] as? String, user.uuidString)
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
        await registrar.flush()
        XCTAssertTrue(sent.isEmpty)
        let nextUser = UUID()
        registrar.bind(userID: nextUser)
        await registrar.flush()
        XCTAssertEqual(sent.first?.userID, nextUser)
        XCTAssertNil(sent.first?.activityPushToken)
    }
}
