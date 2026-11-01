"""Execute the production addition and completion methods with in-memory Swift dependencies.

Requires the Swift CLI (no simulator, SDK, credentials, or network). Extracting
the mutation methods keeps these lifecycle fixes free of test-only app APIs.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ios/App/ReminderListView.swift"

HARNESS = r'''
import Foundation

struct Reminder { let id = UUID(); let text = "Test" }
// PRODUCTION_DRAFT
struct User { let id = UUID() }
struct Session { let user = User() }
struct Auth { var session: Session? = Session() }
enum ReminderBoardLimits {
    static let postItHint = "Capacity"
    static func isAtCapacity(_ count: Int) -> Bool { count >= 5 }
}
enum Failure: Error { case offline }
@MainActor final class ReminderStore {
    static let shared = ReminderStore()
    var calls = 0
    var duringRequest: (() async -> Void)?
    var failure: Error?
    func create(text: String, userID: UUID) async throws -> [Reminder] {
        if let failure { throw failure }
        return [Reminder()]
    }
    func markDone(id: UUID) async throws -> [Reminder] {
        calls += 1
        await duringRequest?()
        if let failure { throw failure }
        return []
    }
}
@MainActor enum ReminderBoardSync {
    static var duringApply: (() -> Void)?
    static func apply(_ reminders: [Reminder], notify: Bool) async {
        duringApply?()
    }
}
enum UIAccessibility {
    enum Notification { case announcement }
    static func post(notification: Notification, argument: String) {}
}
@MainActor final class Board {
    var isReordering = false
    var isDragging = false
    var isLoading = false
    var draft = ReminderDraft()
    var auth = Auth()
    var composerFocused = false
    var error: String?
    var completingIDs: Set<UUID> = []
    var reminders: [Reminder] = []
    var hapticTick = 0
    var errors = 0
    func animateBoard(_ updates: () -> Void) { updates() }
    func presentError(_ message: String) { error = message; errors += 1 }
    // PRODUCTION_MEMBERS
    func add() async { await addReminder() }
    func complete(_ reminder: Reminder) async { await markDone(reminder) }
    var canReorder: Bool { !reorderDisabled }
}

@main struct Regression {
    @MainActor static func main() async {
        let reminder = Reminder()
        let board = Board()
        let store = ReminderStore.shared
        board.reminders = [reminder]
        store.duringRequest = {
            precondition(board.completingIDs.contains(reminder.id), "Pending completion must be busy")
            precondition(!board.canReorder, "Pending completion must block reorder")
            let calls = store.calls
            await board.complete(reminder)
            precondition(store.calls == calls, "Duplicate completion must be suppressed")
        }
        ReminderBoardSync.duringApply = {
            precondition(board.completingIDs.contains(reminder.id), "Publication must remain busy")
        }
        await board.complete(reminder)
        precondition(board.completingIDs.isEmpty, "Success must release busy state")
        // A remote reopen or routine firing restores the same ID to the board.
        board.reminders = [reminder]
        precondition(board.canReorder, "Reopened reminder must allow reorder")
        await board.complete(reminder)
        precondition(store.calls == 2, "Reopened reminder must complete again")

        let failures: [Error] = [Failure.offline, CancellationError()]
        for failure in failures {
            board.reminders = [reminder]
            store.failure = failure
            await board.complete(reminder)
            precondition(board.completingIDs.isEmpty, "Failure must release busy state")
            precondition(board.canReorder, "Failure must restore reorder")
            precondition(board.error != nil, "Failed completion must display its error")
            precondition(board.reminders.count == 1, "Failure must retain the last reminder")
            store.failure = nil
            let calls = store.calls
            await board.complete(reminder)
            precondition(store.calls == calls + 1, "Failure must allow retry")
            precondition(board.reminders.isEmpty, "Successful retry must complete the last reminder")
            precondition(board.error == nil, "Successful retry must show the empty board, not the old failure")
        }
        precondition(board.errors == 2)
        ReminderBoardSync.duringApply = nil

        for failure in failures {
            board.reminders = []
            board.draft.edit("Test")
            store.failure = failure
            await board.add()
            precondition(board.error != nil, "Failed addition must display its error")
            precondition(board.reminders.isEmpty, "Failed addition must not add a reminder")
            precondition(board.draft.canSubmit, "Failed addition must allow retry")
            store.failure = nil
            await board.add()
            precondition(board.reminders.count == 1, "Successful retry must add the reminder")
            precondition(board.error == nil, "Successful addition must dismiss the obsolete error banner")
            precondition(!board.draft.isSubmitting)
        }
        precondition(board.errors == 4)
    }
}
'''


def member(source, declaration):
    start = source.index(declaration)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


@unittest.skipUnless(shutil.which("swiftc"), "Swift compiler is unavailable")
class CompletionBusyTests(unittest.TestCase):
    def test_mutation_retries_clear_errors_and_completion_releases_busy_state(self):
        source = SOURCE.read_text()
        members = "\n".join(member(source, declaration) for declaration in (
            "private func markDone(", "private var reorderDisabled: Bool",
            "private func addReminder(", "private var canAdd: Bool",
            "private var atCapacity: Bool",
        ))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            swift = path / "Regression.swift"
            swift.write_text(HARNESS.replace("// PRODUCTION_MEMBERS", members).replace(
                "// PRODUCTION_DRAFT", (ROOT / "ios/App/ReminderDraft.swift").read_text()))
            subprocess.run(["swiftc", "-parse-as-library", str(swift), "-o", str(path / "test")],
                           check=True, capture_output=True, text=True)
            result = subprocess.run([str(path / "test")], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
