"""Exercise the migration guard through its CI command-line interface."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/check_migration_versions.py"


class MigrationVersionTests(unittest.TestCase):
    def check_files(self, names):
        with tempfile.TemporaryDirectory() as directory:
            for name in names:
                (Path(directory) / name).write_text("-- fixture\n")
            return subprocess.run([sys.executable, str(SCRIPT), directory],
                                  capture_output=True, text=True)

    def test_repository_versions_are_unique(self):
        result = subprocess.run([sys.executable, str(SCRIPT)], cwd="/tmp",
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_duplicate_versions_with_different_descriptions(self):
        for version in ("202610280001", "202610280002", "20261101000100"):
            with self.subTest(version=version):
                names = [f"{version}_{name}.sql" for name in ("first", "second", "third")]
                result = self.check_files(names)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(f"Duplicate migration version {version}", result.stderr)
                for name in names:
                    self.assertIn(name, result.stderr)

    def test_accepts_distinct_versions_and_ignores_non_sql_files(self):
        result = self.check_files(["202610280001_first.sql", "202610280002_first.sql",
                                   "20261101000100_next.sql", "202610280001_notes.md"])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_missing_migrations_and_invalid_names(self):
        for names in ([], ["missing_version.sql"]):
            with self.subTest(names=names):
                self.assertNotEqual(self.check_files(names).returncode, 0)
