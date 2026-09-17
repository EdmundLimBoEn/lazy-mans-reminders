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
}
