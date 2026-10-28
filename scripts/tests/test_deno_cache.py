"""Exercise dependency download retries without contacting the registry."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class DenoCacheTests(unittest.TestCase):
    def run_cache(self, failures):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            deno = path / "deno"
            deno.write_text('''#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$CALL_LOG"
count=$(wc -l < "$CALL_LOG")
[ "$count" -gt "$FAILURES" ]
''')
            sleep = path / "sleep"
            sleep.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$*" >> "$SLEEP_LOG"\n')
            deno.chmod(0o755)
            sleep.chmod(0o755)
            result = subprocess.run(
                ["bash", "scripts/cache-deno-tests.sh"], cwd=ROOT,
                env={**os.environ, "PATH": f"{path}:{os.environ['PATH']}",
                     "CALL_LOG": str(path / "calls"), "SLEEP_LOG": str(path / "sleeps"),
                     "FAILURES": str(failures)},
                capture_output=True, text=True,
            )
            calls = (path / "calls").read_text().splitlines()
            sleeps = (path / "sleeps").read_text().splitlines() if (path / "sleeps").exists() else []
            expected = ["cache"] + [str(p.relative_to(ROOT)) for pattern in (
                "supabase/functions/_shared/*_test.ts",
                "supabase/functions/delete-account/*_test.ts",
            ) for p in sorted(ROOT.glob(pattern))]
            for call in calls:
                self.assertEqual(call.split(), expected)
            return result, calls, sleeps

    def test_success_does_not_retry(self):
        result, calls, sleeps = self.run_cache(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 1)
        self.assertEqual(sleeps, [])

    def test_transient_download_failures_recover(self):
        result, calls, sleeps = self.run_cache(2)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 3)
        self.assertEqual(sleeps, ["5", "10"])

    def test_persistent_download_failure_fails_after_three_attempts(self):
        result, calls, sleeps = self.run_cache(3)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("failed after 3 attempts", result.stderr)
        self.assertEqual(len(calls), 3)
        self.assertEqual(sleeps, ["5", "10"])
