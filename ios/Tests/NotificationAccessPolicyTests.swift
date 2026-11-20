import UserNotifications
import XCTest
@testable import LazyMansReminders

final class NotificationAccessPolicyTests: XCTestCase {
    func testAccessMapsSystemStatus() {
        XCTAssertEqual(NotificationAccessPolicy.access(for: .notDetermined), .ask)
        XCTAssertEqual(NotificationAccessPolicy.access(for: .authorized), .allowed)
        XCTAssertEqual(NotificationAccessPolicy.access(for: .provisional), .allowed)
        XCTAssertEqual(NotificationAccessPolicy.access(for: .ephemeral), .allowed)
        XCTAssertEqual(NotificationAccessPolicy.access(for: .denied), .blocked)
    }

    func testPromptWaitsUntilSessionRestoreFinishes() {
        XCTAssertFalse(
            NotificationAccessPolicy.shouldPrompt(
                isRestoringSession: true,
                status: .notDetermined
            )
        )
        XCTAssertTrue(
            NotificationAccessPolicy.shouldPrompt(
                isRestoringSession: false,
                status: .notDetermined
            )
        )
        XCTAssertFalse(
            NotificationAccessPolicy.shouldPrompt(
                isRestoringSession: false,
                status: .denied
            )
        )
        XCTAssertFalse(
            NotificationAccessPolicy.shouldPrompt(
                isRestoringSession: false,
                status: .authorized
            )
        )
    }

    func testAuthorizationOmitsBadgeAndKeepsAlerts() {
        XCTAssertTrue(NotificationAccessPolicy.authorizationOptions.contains(.alert))
        XCTAssertTrue(NotificationAccessPolicy.authorizationOptions.contains(.sound))
        XCTAssertFalse(NotificationAccessPolicy.authorizationOptions.contains(.badge))
    }

    func testForegroundPresentationDoesNotBanner() {
        XCTAssertTrue(NotificationAccessPolicy.foregroundPresentation.isEmpty)
    }

    func testDeniedAccessOpensSettings() {
        XCTAssertTrue(NotificationAccessPolicy.opensSettings(.blocked))
        XCTAssertFalse(NotificationAccessPolicy.opensSettings(.allowed))
        XCTAssertFalse(NotificationAccessPolicy.opensSettings(.ask))
        XCTAssertTrue(
            NotificationAccessPolicy.footer(.blocked)
                .localizedCaseInsensitiveContains("settings")
        )
    }

    func testReminderCategoryMatchesPushPayload() {
        XCTAssertEqual(NotificationAccessPolicy.reminderCategoryID, "reminder")
        XCTAssertEqual(
            NotificationAccessPolicy.makeReminderCategory().identifier,
            "reminder"
        )
        XCTAssertEqual(
            NotificationAccessPolicy.makeReminderCategory().hiddenPreviewsBodyPlaceholder,
            "New reminder"
        )
    }

    @MainActor
    func testAccountSwitchAndSignOutRemoveOnlyDeliveredReminders() async {
        let gate = AuthSessionGate()
        let alerts = DeliveredAlerts()
        let coordinator = ReminderPublicationCoordinator(
            load: { [] }, publish: { _, _ in }, notificationCenter: alerts
        )
        alerts.add("first-account", category: "reminder")
        alerts.add("unrelated", category: "other")
        let clearBoard = { try! await coordinator.clear() }

        await gate.withLock {
            await gate.shareIdentity(
                previousUserID: UUID(), nextUserID: UUID(),
                clearUserData: {}, clearBoard: clearBoard,
                share: { XCTAssertEqual(alerts.requests.map(\.identifier), ["unrelated"]) }
            )
        }

        alerts.add("second-account", category: "reminder")
        let signedOut = await gate.cleanUp(operations: .init(
            setEndingSession: { _ in }, pauseRegistration: {}, resumeRegistration: {},
            unbind: {}, removeDeviceToken: {}, signOutSDK: {}, clearPublishedSession: {},
            clearUserData: {}, clearBoard: clearBoard
        ))
        XCTAssertTrue(signedOut)
        XCTAssertEqual(alerts.requests.map(\.identifier), ["unrelated"])
    }

    private final class DeliveredAlerts: DeliveredNotificationCenter {
        var requests: [UNNotificationRequest] = []

        func deliveredRequests() async -> [UNNotificationRequest] { requests }

        func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
            requests.removeAll { identifiers.contains($0.identifier) }
        }

        func add(_ identifier: String, category: String) {
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = category
            requests.append(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        }
    }
}
