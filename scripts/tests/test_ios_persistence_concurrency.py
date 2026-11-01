"""Guard the workflow's PR-only cancellation policy without extra dependencies."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class IOSPersistenceConcurrencyTests(unittest.TestCase):
    def setUp(self):
        workflow = (ROOT / ".github/workflows/ios-persistence-checks.yml").read_text()
        block = re.search(r"^concurrency:\n((?:[ \t]+[^\n]*\n)+)", workflow, re.M)
        self.assertIsNotNone(block, "Concurrency must cover the entire workflow")
        self.policy = dict(
            line.strip().split(":", 1) for line in block[1].splitlines()
        )

    def test_only_pull_requests_cancel_in_progress(self):
        self.assertEqual(
            self.policy["cancel-in-progress"].strip(),
            "${{ github.event_name == 'pull_request' }}",
        )

    def test_pr_group_is_stable_and_other_runs_are_unique(self):
        # A ref fallback would let successive main runs evict pending runs even
        # with cancel-in-progress disabled. run_id isolates every non-PR run.
        self.assertEqual(
            self.policy["group"].strip(),
            "${{ github.workflow }}-${{ github.event_name }}-"
            "${{ github.event_name == 'pull_request' && github.event.pull_request.number || github.run_id }}",
        )


if __name__ == "__main__":
    unittest.main()
