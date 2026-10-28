"""Guard the composer's editing policy and exercise failed-save recovery in Swift."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def composer_disabled_expression():
    source = (ROOT / "ios/App/ReminderListView.swift").read_text()
    composer = source.split("private var composer: some View", 1)[1]
    field = composer.split("TextField(", 1)[1].split(".onSubmit", 1)[0]
    return re.search(r"\.disabled\(([^\n]+)\)", field).group(1)


class ComposerSubmissionTests(unittest.TestCase):
    def test_text_field_blocks_edits_during_submission(self):
        # Check the field itself: disabling only the add button loses failed text.
        terms = composer_disabled_expression().split(" || ")
        self.assertIn("draft.isSubmitting", terms)

    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler is unavailable")
    def test_failed_save_restores_text_and_allows_retry(self):
        harness = r'''
import Foundation
@main struct Regression {
    static func main() {
        var draft = ReminderDraft()
        let atCapacity = false, isReordering = false, isDragging = false
        func isDisabled() -> Bool { DISABLED_EXPRESSION }
        func type(_ text: String) {
            if !isDisabled() { draft.edit(text) }
        }
        type("Buy milk")
        precondition(draft.beginSubmission() == "Buy milk")
        precondition(isDisabled())
        type("Call Mum")
        draft.finishSubmission(succeeded: false)
        precondition(draft.text == "Buy milk", "Failed reminder must survive attempted editing")
        precondition(!isDisabled())
        precondition(draft.beginSubmission() == "Buy milk", "Failed reminder must be retryable")
        type("Call Mum")
        draft.finishSubmission(succeeded: true)
        precondition(draft.text.isEmpty)
        precondition(!isDisabled())
        type("Call Mum")
        precondition(draft.beginSubmission() == "Call Mum")
    }
}
'''.replace("DISABLED_EXPRESSION", composer_disabled_expression())
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            main = path / "Regression.swift"
            main.write_text(harness)
            subprocess.run([
                "swiftc", "-parse-as-library", str(ROOT / "ios/App/ReminderDraft.swift"),
                str(main), "-o", str(path / "test"),
            ], check=True, capture_output=True, text=True)
            result = subprocess.run([str(path / "test")], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
