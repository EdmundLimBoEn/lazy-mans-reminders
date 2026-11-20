import Foundation
import XCTest
@testable import NotepadMac

final class MacReminderModelTests: XCTestCase {
    @MainActor
    func testFullBoardBlocksAddWithSharedMessage() async {
        let backend = TestBoard(count: 16)
        let model = MacReminderModel(backend: backend)
        await model.refresh()

        XCTAssertEqual(ReminderBoardLimits.maxActive, 16)
        XCTAssertTrue(model.isFull)
        let saved = await model.add("Another reminder")
        XCTAssertFalse(saved)
        XCTAssertTrue(backend.added.isEmpty)
        XCTAssertEqual(model.errorMessage, ReminderBoardLimits.postItHint)
    }

    @MainActor
    func testTrimsInputAndKeepsTheServerCharacterLimit() async {
        let backend = TestBoard()
        let model = MacReminderModel(backend: backend)
        await model.refresh()

        let emptySaved = await model.add(" \n\t ")
        XCTAssertFalse(emptySaved)
        // Each decomposed letter has two Unicode scalars.
        let limit = String(repeating: "e\u{301}", count: 250)
        let tooLongSaved = await model.add(limit + "x")
        XCTAssertFalse(tooLongSaved)
        XCTAssertEqual(model.errorMessage, "Keep each reminder to 500 characters.")

        let saved = await model.add(" \n" + limit + "\t ")
        XCTAssertTrue(saved)
        XCTAssertEqual(backend.added, [limit])
        XCTAssertEqual(model.reminders.map(\.text), [limit])
    }

    @MainActor
    func testCompleteRemovesTheReminderAndFreesSpace() async throws {
        let backend = TestBoard(count: 16)
        let model = MacReminderModel(backend: backend)
        await model.refresh()
        let reminder = try XCTUnwrap(model.reminders.first)

        await model.complete(reminder)
        XCTAssertEqual(model.reminders.count, 15)
        XCTAssertFalse(model.reminders.contains(reminder))
        XCTAssertFalse(model.isFull)
        let saved = await model.add("Use the free slot")
        XCTAssertTrue(saved)
        XCTAssertTrue(model.isFull)
    }

    @MainActor
    func testSignOutClearsBoardAndSession() async {
        let backend = TestBoard(count: 2)
        let model = MacReminderModel(backend: backend)
        await model.refresh()

        await model.signOut()
        XCTAssertFalse(model.isSignedIn)
        XCTAssertFalse(model.hasBoard)
        XCTAssertTrue(model.reminders.isEmpty)
        XCTAssertEqual(backend.signOuts, 1)
    }

    @MainActor
    func testOfflineKeepsBoardAndServerCapacityUsesSharedMessage() async {
        let backend = TestBoard(count: 2)
        let model = MacReminderModel(backend: backend)
        await model.refresh()
        let previousBoard = model.reminders

        backend.failure = URLError(.notConnectedToInternet)
        await model.refresh()
        XCTAssertEqual(model.errorMessage, "You’re offline.")
        XCTAssertEqual(model.reminders, previousBoard)
        XCTAssertTrue(model.isSignedIn)
        XCTAssertEqual(backend.signOuts, 0)

        backend.failure = ReminderStore.StoreError.atCapacity
        let saved = await model.add("Added on another device")
        XCTAssertFalse(saved)
        XCTAssertEqual(model.errorMessage, ReminderBoardLimits.postItHint)
    }

    @MainActor
    func testDeletedAndSuspendedAccountsClearTheBoard() async {
        let failures: [(any Error, String)] = [
            (MacSessionError.ended, "Sign in again to continue."),
            (MacSessionError.suspended, "This account is suspended."),
            (ReminderStore.StoreError.requestFailed(401), "Sign in again to continue."),
        ]
        for (failure, message) in failures {
            let backend = TestBoard(count: 2)
            let model = MacReminderModel(backend: backend)
            await model.refresh()

            backend.failure = failure
            await model.refresh()
            XCTAssertEqual(model.errorMessage, message)
            XCTAssertFalse(model.isSignedIn)
            XCTAssertTrue(model.reminders.isEmpty)
            XCTAssertEqual(backend.signOuts, 1)
        }
    }
}

@MainActor
private final class TestBoard: MacBoardBackend {
    private let owner = UUID()
    private var reminders: [Reminder] = []
    private(set) var hasSession = true
    private(set) var added: [String] = []
    private(set) var signOuts = 0
    var failure: (any Error)?

    init(count: Int = 0) {
        for index in 0..<count {
            append("Reminder \(index + 1)")
        }
    }

    func refresh(performMaintenance: Bool) async throws -> [Reminder] {
        if let failure { throw failure }
        return reminders
    }

    func add(_ text: String) async throws -> [Reminder] {
        if let failure { throw failure }
        added.append(text)
        append(text)
        return reminders
    }

    func complete(_ id: UUID) async throws -> [Reminder] {
        reminders.removeAll { $0.id == id }
        return reminders
    }

    func signOut() async {
        reminders = []
        hasSession = false
        signOuts += 1
    }

    private func append(_ text: String) {
        reminders.append(Reminder(
            id: UUID(), userID: owner, text: text, sortOrder: (reminders.last?.sortOrder ?? -1) + 1,
            isDone: false, createdAt: Date()
        ))
    }
}
