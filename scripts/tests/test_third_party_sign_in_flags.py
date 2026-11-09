from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/check-third-party-sign-in-flags.py"

BPLIST00_DF = b"bplist00" + bytes([0xDF]) + b"\x00\x01\x02\x03"


def init_repo(directory: Path) -> None:
    subprocess.run(
        ["git", "init", "-q"],
        cwd=directory,
        check=True,
        capture_output=True,
        text=True,
    )
    subprocess.run(
        ["git", "config", "user.email", "flags-off@test"],
        cwd=directory,
        check=True,
        capture_output=True,
        text=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "flags-off"],
        cwd=directory,
        check=True,
        capture_output=True,
        text=True,
    )


def commit_file(directory: Path, relpath: str, data: bytes) -> None:
    path = directory / relpath
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    subprocess.run(
        ["git", "add", "--", relpath],
        cwd=directory,
        check=True,
        capture_output=True,
        text=True,
    )
    subprocess.run(
        ["git", "commit", "-q", "-m", relpath],
        cwd=directory,
        check=True,
        capture_output=True,
        text=True,
    )


def run_checker(directory: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT)],
        cwd=directory,
        capture_output=True,
        text=True,
    )


class ThirdPartySignInFlagsTests(unittest.TestCase):
    def test_binary_plist_does_not_crash_the_repo_scan(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            init_repo(root)
            commit_file(root, "Info.plist", BPLIST00_DF)
            result = run_checker(root)
            combined = result.stderr + result.stdout
            self.assertNotIn("UnicodeDecodeError", combined, combined)
            self.assertEqual(result.returncode, 0, combined)
            self.assertIn("GROK_SIGN_IN_ENABLED", result.stdout)

    def test_binary_hillclimb_capture_named_like_a_plist_is_skipped(self) -> None:
        png = (
            b"\x89PNG\r\n\x1a\n"
            + b"\x00\x00\x00\rIHDR"
            + bytes(13)
            + b"\x00\x00\x00\x00IEND"
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            init_repo(root)
            commit_file(root, "hillclimb/rounds/1/signin-light.plist", png)
            result = run_checker(root)
            combined = result.stderr + result.stdout
            self.assertNotIn("UnicodeDecodeError", combined, combined)
            self.assertEqual(result.returncode, 0, combined)

    def test_enabled_flag_in_utf8_xcconfig_still_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            init_repo(root)
            commit_file(
                root,
                "ios/Config.example.xcconfig",
                b"GROK_SIGN_IN_ENABLED = YES\n",
            )
            result = run_checker(root)
            self.assertEqual(result.returncode, 1, result.stderr or result.stdout)
            self.assertIn("GROK_SIGN_IN_ENABLED", result.stderr)


if __name__ == "__main__":
    unittest.main()
