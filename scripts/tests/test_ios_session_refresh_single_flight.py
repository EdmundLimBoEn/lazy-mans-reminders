from pathlib import Path
import unittest

from test_ios_background_refresh import block
from test_ios_completion_busy import member

ROOT = Path(__file__).resolve().parents[2]


class SessionRefreshSingleFlightTests(unittest.TestCase):
    def test_overlapping_loads_join_one_in_flight_refresh(self):
        source = (ROOT / "ios/Shared/ReminderStore.swift").read_text()
        load = member(source, "private func loadFreshSession(")
        self.assertIn("if let inFlightRefresh", load)
        self.assertLess(load.index("if let inFlightRefresh"), load.index("Task {"))
        self.assertIn("await inFlightRefresh.value", load)
        save = member(source, "func saveSession(")
        self.assertIn("freshSession(for: userID)", save)
        self.assertIn("!session.isFresh()", save)

    def test_silent_push_and_notifications_wait_for_restoration(self):
        silent = (ROOT / "ios/App/SilentPushRefresh.swift").read_text()
        self.assertIn("waitForSession:", silent)
        work, _ = block(silent, "let work = Task")
        self.assertLess(work.index("await waitForSession()"), work.index("store.refresh("))

        app = (ROOT / "ios/App/AppDelegate.swift").read_text()
        remote, _ = block(app, "didReceiveRemoteNotification")
        self.assertIn("waitForSession:", remote)
        self.assertIn("AuthManager.shared.waitForRestoration()", remote)
        self.assertLess(
            remote.index("waitForRestoration()"),
            remote.index("completion:"),
        )

        present, _ = block(app, "willPresent notification")
        self.assertLess(
            present.index("AuthManager.shared.waitForRestoration()"),
            present.index("ReminderStore.shared.refresh()"),
        )
        received, _ = block(app, "didReceive response")
        self.assertLess(
            received.index("AuthManager.shared.waitForRestoration()"),
            received.index("ReminderStore.shared.refresh()"),
        )

    def test_share_session_adopts_a_fresh_rotated_store_session(self):
        source = (ROOT / "ios/App/AuthManager.swift").read_text()
        sharing = member(source, "private func shareSession(")
        self.assertIn("freshSession(for:", sharing)
        self.assertIn("!incoming.isFresh()", sharing)
        self.assertIn("client.auth.setSession(", sharing)
        save = member(sharing, "share:")
        self.assertIn("try await ReminderStore.shared.saveSession(", save)
        self.assertNotIn("try?", save)
        self.assertNotIn("catch", save)


if __name__ == "__main__":
    unittest.main()
