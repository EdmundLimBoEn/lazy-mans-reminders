"""Check the UI wiring for the native shared-session ordering regression tests."""
from pathlib import Path
import unittest

from test_ios_completion_busy import member

ROOT = Path(__file__).resolve().parents[2]


class SharedSessionReadinessTests(unittest.TestCase):
    def test_session_replacement_invalidates_readiness_before_publication(self):
        source = (ROOT / "ios/App/AuthManager.swift").read_text()
        session = member(source, "@Published private(set) var session: Session?")
        self.assertIn("willSet { isSharedSessionReady = false }", session)
        self.assertIn("@Published private(set) var isSharedSessionReady = false", source)
        sharing = member(source, "private func shareSession(")
        self.assertIn("didShare: { self.isSharedSessionReady = true }", sharing)

    def test_storage_errors_reach_the_publication_retry(self):
        source = (ROOT / "ios/App/AuthManager.swift").read_text()
        sharing = member(source, "private func shareSession(")
        self.assertIn("try await authSessionGate.shareIdentity(", sharing)
        save = member(sharing, "share:")
        self.assertIn("try await ReminderStore.shared.saveSession(", save)
        self.assertNotIn("try?", save)
        self.assertNotIn("catch", save)

    def test_active_board_task_restarts_when_shared_session_becomes_ready(self):
        source = (ROOT / "ios/App/ReminderListView.swift").read_text()
        task = member(source, ".task(id: scenePhase == .active && auth.isSharedSessionReady)")
        self.assertIn("guard scenePhase == .active else { return }", task)
        self.assertIn("await refresh()", task)
        refresh = member(source, "private func refresh()")
        self.assertLess(
            refresh.index("guard auth.isSharedSessionReady else { return }"),
            refresh.index("ReminderBoardSync.refreshForeground()"),
        )
