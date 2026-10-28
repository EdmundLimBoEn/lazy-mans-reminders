"""Guard the app/widget Keychain sharing configuration, including regeneration."""
import plistlib
import re
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SharedKeychainConfigurationTests(unittest.TestCase):
    def test_both_targets_authorize_the_same_prefixed_keychain_group(self):
        expected = "$(AppIdentifierPrefix)$(APP_GROUP_ID)"
        for directory, entitlement in [
            ("App", "LazyMansReminders.entitlements"),
            ("Widget", "ReminderWidget.entitlements"),
        ]:
            with self.subTest(target=directory):
                with (ROOT / "ios" / directory / entitlement).open("rb") as source:
                    entitlements = plistlib.load(source)
                with (ROOT / "ios" / directory / "Info.plist").open("rb") as source:
                    info = plistlib.load(source)
                self.assertEqual(entitlements["keychain-access-groups"], [expected])
                self.assertEqual(info["SHARED_KEYCHAIN_ACCESS_GROUP"], expected)

    def test_generator_preserves_both_targets_configuration(self):
        spec = (ROOT / "ios/project.yml").read_text()
        for target in ("LazyMansReminders", "ReminderWidgetExtension"):
            # Target contents use at least four spaces; split only at the next target.
            section = re.split(r"\n  (?=\S)", spec.split(f"\n  {target}:\n", 1)[1])[0]
            self.assertIn('SHARED_KEYCHAIN_ACCESS_GROUP: "$(AppIdentifierPrefix)$(APP_GROUP_ID)"', section)
            self.assertIn('keychain-access-groups:\n          - "$(AppIdentifierPrefix)$(APP_GROUP_ID)"', section)


if __name__ == "__main__":
    unittest.main()
