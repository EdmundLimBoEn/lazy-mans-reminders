import importlib.util
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/check-third-party-sign-in-flags.py"


def load_flags():
    spec = importlib.util.spec_from_file_location("check_third_party_sign_in_flags", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ThirdPartySignInFlagsTests(unittest.TestCase):
    def test_read_source_decodes_binary_plist(self):
        flags = load_flags()
        with tempfile.NamedTemporaryFile(delete=False) as handle:
            path = Path(handle.name)
        path.write_bytes(plistlib.dumps({"GROK_SIGN_IN_ENABLED": False}, fmt=plistlib.FMT_BINARY))
        try:
            text = flags.read_source(path)
        finally:
            path.unlink()
        self.assertIsNotNone(text)
        self.assertIn("GROK_SIGN_IN_ENABLED", text)
        self.assertEqual(flags.check_file("Info.plist", text), [])

    def test_binary_plist_reports_enabled_flag(self):
        flags = load_flags()
        with tempfile.NamedTemporaryFile(delete=False) as handle:
            path = Path(handle.name)
        path.write_bytes(plistlib.dumps({"GROK_SIGN_IN_ENABLED": True}, fmt=plistlib.FMT_BINARY))
        try:
            text = flags.read_source(path)
        finally:
            path.unlink()
        hits = flags.check_file("Info.plist", text)
        self.assertTrue(any("GROK_SIGN_IN_ENABLED" in hit for hit in hits), hits)

    def test_repo_scan_accepts_tracked_binary_plists(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT)],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertIn("GROK_SIGN_IN_ENABLED", result.stdout)


if __name__ == "__main__":
    unittest.main()
