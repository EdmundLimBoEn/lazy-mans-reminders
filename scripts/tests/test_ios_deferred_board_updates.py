"""Exercise the production cache replay with controlled Swift actor suspension."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_ios_completion_busy import member

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ios/App/ReminderListView.swift"

HARNESS = r'''
import Foundation

@MainActor final class ReminderStore {
    static let shared = ReminderStore()
    var snapshot = [1, 2]
    var reads = 0
    var duringRead: (() -> Void)?
    func cached() async -> [Int] {
        reads += 1
        let result = snapshot
        let callback = duringRead
        duringRead = nil
        callback?()
        return result
    }
}
@MainActor final class Board {
    var isDragging = false
    var isReordering = false
    var hasDeferredBoardUpdate = false
    var boardRevision = 0
    var reminders = [1, 2]
    // PRODUCTION_MEMBER
    func replay() async { await replayDeferredBoardUpdate() }
}
@main struct Regression {
    @MainActor static func main() async {
        let store = ReminderStore.shared
        let board = Board()
        // Cancelled and unchanged drops both end without a reorder request.
        for _ in 0..<2 {
            board.isDragging = true
            board.boardRevision += 1
            board.hasDeferredBoardUpdate = true
            let before = board.reminders
            store.snapshot = [3]
            await board.replay()
            precondition(board.reminders == before)
            precondition(board.hasDeferredBoardUpdate)
            store.snapshot = [4, 5] // Coalesce to the latest cache, not the first notification.
            board.isDragging = false
            await board.replay()
            precondition(board.reminders == [4, 5])
            precondition(!board.hasDeferredBoardUpdate)
        }
        // A changed drop must wait for saving (success or failure cleanup).
        for _ in 0..<2 {
            board.isDragging = true
            board.isReordering = true
            board.hasDeferredBoardUpdate = true
            store.snapshot = [6]
            board.isDragging = false
            await board.replay()
            precondition(board.reminders == [4, 5])
            precondition(board.hasDeferredBoardUpdate)
            board.isReordering = false
            await board.replay()
            precondition(board.reminders == [6])
            board.reminders = [4, 5]
        }
        // A new drag during the actor read must retain the pending update.
        board.hasDeferredBoardUpdate = true
        store.duringRead = {
            board.isDragging = true
            board.boardRevision += 1
        }
        await board.replay()
        precondition(board.reminders == [4, 5])
        precondition(board.hasDeferredBoardUpdate)
        store.snapshot = [7]
        board.isDragging = false
        await board.replay()
        precondition(board.reminders == [7])
        // Even a complete drag/save cycle during the read invalidates its snapshot.
        board.hasDeferredBoardUpdate = true
        store.duringRead = {
            board.boardRevision += 1
            store.snapshot = [8]
        }
        await board.replay()
        precondition(board.reminders == [8])
        let reads = store.reads
        await board.replay()
        precondition(store.reads == reads, "Idle state changes must not reload without an update")
    }
}
'''


class DeferredBoardUpdateTests(unittest.TestCase):
    def test_notifications_and_both_busy_states_trigger_replay(self):
        source = SOURCE.read_text()
        notification = member(source, ".onReceive(NotificationCenter.default.publisher(for: .didUpdateReminders))")
        self.assertIn("hasDeferredBoardUpdate = true", notification)
        self.assertIn("await replayDeferredBoardUpdate()", notification)
        lifecycle = member(source, ".task(id: isDragging || isReordering)")
        self.assertIn("await replayDeferredBoardUpdate()", lifecycle)

    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler is unavailable")
    def test_deferred_replay_and_interrupted_cache_reads(self):
        production = member(SOURCE.read_text(), "private func replayDeferredBoardUpdate()")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            swift = path / "Regression.swift"
            swift.write_text(HARNESS.replace("// PRODUCTION_MEMBER", production))
            result = subprocess.run(
                ["swiftc", "-parse-as-library", str(swift), "-o", str(path / "test")],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run([str(path / "test")], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
