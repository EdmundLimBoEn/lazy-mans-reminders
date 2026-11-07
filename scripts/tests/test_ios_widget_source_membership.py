"""Reject widget/app source lists that omit shared session credential files."""
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_checker():
    path = ROOT / "scripts/check-ios-target-membership.py"
    spec = importlib.util.spec_from_file_location("check_ios_target_membership", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


checker = load_checker()

WIDGET_MISSING_STORAGE = r'''
		AA0000000000000000000001 /* ReminderWidgetExtension */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AA0000000000000000000002 /* Debug */;
			buildPhases = (
				AA0000000000000000000003 /* Sources */,
				AA0000000000000000000004 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = ReminderWidgetExtension;
			productName = ReminderWidgetExtension;
			productReference = AA0000000000000000000005 /* ReminderWidgetExtension.appex */;
			productType = "com.apple.product-type.app-extension";
		};
		AA0000000000000000000011 /* LazyMansReminders */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AA0000000000000000000012 /* Debug */;
			buildPhases = (
				AA0000000000000000000013 /* Sources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = LazyMansReminders;
			productName = LazyMansReminders;
			productType = "com.apple.product-type.application";
		};
		AA0000000000000000000003 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				AA0000000000000000000021 /* ReminderStore.swift in Sources */,
				AA0000000000000000000022 /* Reminder.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AA0000000000000000000013 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				AA0000000000000000000031 /* SharedSessionStorage.swift in Sources */,
				AA0000000000000000000032 /* ReminderStore.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
'''

WIDGET_WITH_STORAGE = WIDGET_MISSING_STORAGE.replace(
    "AA0000000000000000000021 /* ReminderStore.swift in Sources */,",
    "AA0000000000000000000020 /* SharedSessionStorage.swift in Sources */,\n"
    "				AA0000000000000000000021 /* ReminderStore.swift in Sources */,",
)


class WidgetSourceMembershipTests(unittest.TestCase):
    def test_project_spec_compiles_shared_session_files_in_app_and_widget(self):
        self.assertEqual(checker.check_spec(ROOT), [])

    def test_spec_rejects_widget_exclude_of_session_storage(self):
        spec = (ROOT / "ios/project.yml").read_text(encoding="utf-8")
        broken = spec.replace(
            "  ReminderWidgetExtension:\n    type: app-extension\n    platform: iOS\n    sources:\n"
            "      - path: Widget\n      - path: Shared\n        excludes:\n"
            "          - PrivacyInfo.xcprivacy\n",
            "  ReminderWidgetExtension:\n    type: app-extension\n    platform: iOS\n    sources:\n"
            "      - path: Widget\n      - path: Shared\n        excludes:\n"
            "          - PrivacyInfo.xcprivacy\n          - SharedSessionStorage.swift\n",
        )
        self.assertNotEqual(broken, spec)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shared = root / "ios/Shared"
            shared.mkdir(parents=True)
            (root / "ios/project.yml").write_text(broken, encoding="utf-8")
            for path in (ROOT / "ios/Shared").glob("*.swift"):
                (shared / path.name).write_text(path.read_text(encoding="utf-8"), encoding="utf-8")
            errors = checker.check_spec(root)
        self.assertTrue(any("ReminderWidgetExtension omits Shared Swift files" in error and "SharedSessionStorage.swift" in error for error in errors), errors)

    def test_pbxproj_rejects_widget_without_session_storage(self):
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".pbxproj", delete=False) as handle:
            handle.write(WIDGET_MISSING_STORAGE)
            path = Path(handle.name)
        try:
            errors = checker.check_pbxproj(path)
        finally:
            path.unlink()
        self.assertTrue(
            any("ReminderWidgetExtension Compile Sources omit SharedSessionStorage.swift" in error for error in errors),
            errors,
        )

    def test_cli_passes_without_generated_project(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/check-ios-target-membership.py")],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_cli_requires_generated_project_when_asked(self):
        missing = Path(tempfile.mkdtemp()) / "project.pbxproj"
        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/check-ios-target-membership.py"),
                "--require-pbxproj",
                "--pbxproj",
                str(missing),
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing", result.stderr.lower())

    def test_pbxproj_accepts_widget_with_session_storage(self):
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".pbxproj", delete=False) as handle:
            handle.write(WIDGET_WITH_STORAGE)
            path = Path(handle.name)
        try:
            self.assertEqual(checker.check_pbxproj(path), [])
        finally:
            path.unlink()


if __name__ == "__main__":
    unittest.main()
