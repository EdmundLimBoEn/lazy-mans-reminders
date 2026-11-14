"""Guard clipboard privacy and execute the production paste flow with fake metadata."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_ios_completion_busy import member

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ios/App/ReminderListView.swift"


class ClipboardOfferTests(unittest.TestCase):
    def test_detection_never_reads_clipboard_payload(self):
        board = SOURCE.read_text()
        card = (ROOT / "ios/App/ClipboardOfferCard.swift").read_text()
        detection = member(board, "private func updateClipboardSnapshot()")
        self.assertIn("pasteboard.hasStrings", detection)
        self.assertIn("pasteboard.changeCount", detection)
        self.assertNotRegex(
            board + card,
            r"(?:UIPasteboard\.general|pasteboard)\.(?:string|strings|items|data|value)\b",
        )
        self.assertIn("PasteButton(payloadType: String.self, onPaste: onPaste)", card)
        self.assertNotIn("createReminder", detection)

    def test_offer_requires_successful_load_and_existing_capacity_policy(self):
        source = SOURCE.read_text()
        offer = member(source, "private var showClipboardOffer: Bool")
        self.assertIn("hasLoaded: hasLoadedSuccessfully", offer)
        refresh = member(source, "private func refresh()")
        self.assertIn("hasLoadedSuccessfully = true", refresh.split("} catch", 1)[0])
        self.assertNotIn("hasLoadedSuccessfully = true", refresh.split("} catch", 1)[1])
        self.assertIn("ReminderBoardLimits.isAtCapacity(reminders.count)", source)

    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler is unavailable")
    def test_paste_submission_preserves_draft_and_consumes_each_offer_once(self):
        source = SOURCE.read_text()
        members = "\n".join(member(source, declaration) for declaration in (
            "private func addFromClipboard(", "private func createReminder(",
            "private var canAdd: Bool", "private var atCapacity: Bool",
            "private var reorderDisabled: Bool",
        ))
        harness = r'''
import Foundation
struct Reminder { let id = UUID() }
struct User { let id = UUID() }
struct Session { let user = User() }
struct Auth { var session: Session? = Session(); var isSharedSessionReady = true }
enum ScenePhase { case active, background }
enum ReminderBoardLimits {
    static let postItHint = "Capacity"
    static func isAtCapacity(_ count: Int) -> Bool { count >= 16 }
}
enum Failure: Error { case rejected }
@MainActor final class ReminderStore {
    static let shared = ReminderStore()
    var calls = 0
    var text = ""
    var failure = false
    var duringCreate: (() async -> Void)?
    func create(text: String, userID: UUID) async throws -> [Reminder] {
        calls += 1
        self.text = text
        await duringCreate?()
        if failure { throw Failure.rejected }
        return [Reminder()]
    }
}
@MainActor enum ReminderBoardSync {
    static var calls = 0
    static func apply(_ reminders: [Reminder], notify: Bool) async { calls += 1 }
}
@MainActor enum UIAccessibility {
    enum Notification { case announcement }
    static var announcement = ""
    static func post(notification: Notification, argument: String) { announcement = argument }
}
@MainActor final class Board {
    var clipboardLastHandledChangeCount = -1
    var clipboardSnapshot = ClipboardOfferPolicy.Snapshot(hasStrings: true, changeCount: 42)
    var isAddingClipboard = false
    var scenePhase = ScenePhase.active
    var auth = Auth()
    var hasLoadedSuccessfully = true
    var isLoading = false
    var showAccount = false
    var isReordering = false
    var isDragging = false
    var draft = ReminderDraft()
    var error: String?
    var reminders: [Reminder] = []
    var completingIDs: Set<UUID> = []
    var hapticTick = 0
    func updateClipboardSnapshot() {} // Injected metadata, never UIPasteboard.
    func animateBoard(_ updates: () -> Void) { updates() }
    func presentError(_ message: String) { error = message }
    // MEMBERS
    func paste(_ text: String, count: Int = 42) async {
        await addFromClipboard([text], changeCount: count)
    }
    var canCompose: Bool { canAdd }
    var canReorder: Bool { !reorderDisabled }
}
@main struct Regression {
    @MainActor static func main() async {
        let store = ReminderStore.shared
        let board = Board()
        board.draft.edit("Unsent draft")
        store.duringCreate = {
            precondition(board.isAddingClipboard)
            precondition(!board.canCompose && !board.canReorder)
            await board.paste("Duplicate callback")
            precondition(store.calls == 1)
        }
        await board.paste(" \n Buy milk \t")
        precondition(store.calls == 1 && store.text == "Buy milk")
        precondition(board.draft.text == "Unsent draft")
        precondition(board.clipboardLastHandledChangeCount == 42)
        precondition(!board.isAddingClipboard && board.hapticTick == 1)
        precondition(ReminderBoardSync.calls == 1)
        precondition(UIAccessibility.announcement == "Reminder added")
        await board.paste("Duplicate")
        precondition(store.calls == 1)
        store.duringCreate = nil

        let blank = Board()
        await blank.paste(" \t\n")
        precondition(store.calls == 1 && blank.clipboardLastHandledChangeCount == 42)

        let full = Board()
        full.reminders = (0..<16).map { _ in Reminder() }
        await full.paste("No room")
        precondition(store.calls == 1 && full.error == ReminderBoardLimits.postItHint)
        precondition(full.clipboardLastHandledChangeCount == 42)

        let changed = Board()
        changed.clipboardSnapshot.changeCount = 43
        await changed.paste("Stale delivery")
        precondition(store.calls == 1 && changed.clipboardLastHandledChangeCount == 42)
        await changed.paste("Fresh delivery", count: 43)
        precondition(store.calls == 2)

        let failed = Board()
        failed.draft.edit("Keep this")
        store.failure = true // Includes a store/server capacity race.
        await failed.paste("Rejected")
        precondition(store.calls == 3 && failed.error != nil)
        precondition(!failed.isAddingClipboard && failed.hapticTick == 0)
        precondition(failed.draft.text == "Keep this")
        await failed.paste("No automatic retry")
        precondition(store.calls == 3)
    }
}
'''.replace("// MEMBERS", members)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            swift = path / "Regression.swift"
            swift.write_text(harness)
            result = subprocess.run([
                "swiftc", "-parse-as-library", str(swift),
                str(ROOT / "ios/App/ClipboardOfferPolicy.swift"),
                str(ROOT / "ios/App/ReminderDraft.swift"), "-o", str(path / "test"),
            ], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(path / "test")], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
