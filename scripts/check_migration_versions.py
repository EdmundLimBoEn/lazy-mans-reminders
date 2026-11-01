"""Reject migration version collisions before applying any SQL."""
import argparse
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path,
                        default=ROOT / "supabase/migrations")
    directory = parser.parse_args().directory
    files = sorted(directory.glob("*.sql"))
    if not files:
        print(f"No migrations found in {directory}", file=sys.stderr)
        return 1
    versions = {}
    errors = []
    for path in files:
        match = re.fullmatch(r"([0-9]+)_.+\.sql", path.name)
        if not match:
            errors.append(f"Invalid migration filename: {path.name}")
            continue
        version = match[1]
        if version in versions:
            errors.append(f"Duplicate migration version {version}: "
                          f"{versions[version]} and {path.name}")
        else:
            versions[version] = path.name
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Checked {len(files)} migrations: all version prefixes are unique.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
