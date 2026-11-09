"""Source contract: APNs token rotation deletes this device's old registration."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def member(source: str, marker: str) -> str:
    start = source.index("{", source.index(marker))
    depth = 1
    end = start + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start + 1:end - 1]


class RotatedDeviceTokenTests(unittest.TestCase):
    def test_auth_manager_deletes_superseded_tokens_before_upsert(self):
        source = (ROOT / "ios/App/AuthManager.swift").read_text()
        registrar = source[
            source.index("lazy var pushRegistration"):
            source.index("private struct LockScreenPrefs")
        ]
        self.assertIn('.delete().eq("token", value: token).eq("user_id", value: userID)', registrar)
        self.assertIn("AuthSessionGate.verifyAbsence(rows)", registrar)
        self.assertIn('.upsert(registration, onConflict: "token")', registrar)
        self.assertLess(registrar.index(".delete()"), registrar.index(".upsert("))
        removal = member(source, "private func removeDeviceToken()")
        self.assertIn("pushRegistration.removeRegistrations(userID: userID)", removal)
        self.assertNotIn("pushRegistration.deviceToken", removal)

    def test_registrar_queues_the_replaced_token_for_confirmed_delete(self):
        source = (ROOT / "ios/App/PushTokenRegistrar.swift").read_text()
        record = member(source, "func recordDeviceToken(_ token: String)")
        self.assertIn("SupersededToken(token: oldToken, userID: userID)", record)
        flush = member(source, "func flush() async")
        self.assertIn("try await removeSupersededTokens()", flush)
        self.assertIn("needsRetry = true", flush)


if __name__ == "__main__":
    unittest.main()
