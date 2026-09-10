import XCTest
@testable import LazyMansReminders

@MainActor
final class DeviceRegistrationTests: XCTestCase {
    func testColdLaunchWaitsForAuthThenUploadsWithoutAView() async {
        var authenticated = false
        var deviceToken: String?
        var uploads: [String] = []
        let registration = DeviceRegistrationCoordinator(
            readyToken: { authenticated ? deviceToken : nil },
            upload: { uploads.append($0) }
        )

        // The activity token arrives before APNs and the restored auth session.
        await registration.reconcile().value
        deviceToken = "device-token"
        await registration.reconcile().value
        XCTAssertTrue(uploads.isEmpty)

        authenticated = true
        await registration.reconcile().value
        XCTAssertEqual(uploads, ["device-token"])
    }

    func testColdLaunchWaitsForAPNsAfterAuthRestores() async {
        var deviceToken: String?
        var uploads: [String] = []
        let registration = DeviceRegistrationCoordinator(
            readyToken: { deviceToken },
            upload: { uploads.append($0) }
        )

        await registration.reconcile().value
        XCTAssertTrue(uploads.isEmpty)
        deviceToken = "device-token"
        await registration.reconcile().value
        XCTAssertEqual(uploads, ["device-token"])
    }

    func testTokenChangeDuringUploadReconcilesAgainSerially() async {
        var token = "old-device-token"
        var uploads: [String] = []
        var resumeUpload: CheckedContinuation<Void, Never>?
        let started = expectation(description: "First upload started")
        let registration = DeviceRegistrationCoordinator(
            readyToken: { token },
            upload: { value in
                uploads.append(value)
                if uploads.count == 1 {
                    await withCheckedContinuation { continuation in
                        resumeUpload = continuation
                        started.fulfill()
                    }
                }
            }
        )

        let initial = registration.reconcile()
        await fulfillment(of: [started], timeout: 2)
        token = "new-device-token"
        registration.reconcile()
        XCTAssertEqual(uploads, ["old-device-token"])
        resumeUpload?.resume()
        await initial.value
        XCTAssertEqual(uploads, ["old-device-token", "new-device-token"])
    }
}
