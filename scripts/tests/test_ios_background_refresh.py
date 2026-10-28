"""Lifecycle wiring regressions, runnable without Apple's SDK.

These source-contract tests check the actual Scene modifier (a scheduler unit
test alone cannot catch a missing SwiftUI lifecycle hook). Device scheduling
and SwiftUI callback delivery still require native verification.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def block(source, marker):
    start = source.index("{", source.index(marker))
    depth = 1
    end = start + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start + 1:end - 1], source[end:]


class BackgroundRefreshLifecycleTests(unittest.TestCase):
    def test_app_scene_schedules_only_when_entering_background(self):
        source = (ROOT / "ios/App/LazyMansRemindersApp.swift").read_text()
        self.assertRegex(source, r"@Environment\(\\\.scenePhase\)\s+private var scenePhase")
        body, _ = block(source, "var body: some Scene")
        _, modifiers = block(body, "WindowGroup")
        # Must attach to the Scene, outside ContentView and its auth lifecycle.
        self.assertRegex(modifiers, r"^\s*\.onChange\(of: scenePhase\)")
        callback, _ = block(modifiers, ".onChange(of: scenePhase)")
        self.assertRegex(callback, r"^\s*_, phase in")
        background, remainder = block(callback, "if phase == .background")
        self.assertEqual(background.strip(), "BackgroundBoardRefresh.schedule()")
        self.assertEqual(remainder.strip(), "")
        self.assertEqual(callback.count("BackgroundBoardRefresh.schedule()"), 1)

    def test_launch_registration_and_task_rescheduling_remain_connected(self):
        delegate = (ROOT / "ios/App/AppDelegate.swift").read_text()
        launch, _ = block(delegate, "didFinishLaunchingWithOptions")
        self.assertIn("BackgroundBoardRefresh.register()", launch)
        refresh = (ROOT / "ios/App/BackgroundBoardRefresh.swift").read_text()
        handler, _ = block(refresh, "private static func handle(")
        self.assertTrue(handler.lstrip().startswith("schedule()"))


if __name__ == "__main__":
    unittest.main()
