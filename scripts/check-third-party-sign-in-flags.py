#!/usr/bin/env python3
"""Fail if a committed xcconfig or Info.plist default enables third-party sign-in.

Looks at tracked *.xcconfig, *Info.plist, *.plist, and ios/project.yml (the
XcodeGen source for Info.plist defaults). Missing flags are OK so this passes
on main today. GROK_SIGN_IN_ENABLED / CHATGPT_SIGN_IN_ENABLED = NO also pass,
which is the layout used by the sign-in feature branch.

Local ios/Config.xcconfig is gitignored and is not scanned, so a developer can
turn a flag on for a device build without tripping CI.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

FLAGS = ("GROK_SIGN_IN_ENABLED", "CHATGPT_SIGN_IN_ENABLED")
ENABLED_VALUES = {"yes", "true", "1"}
FLAG_GROUP = "|".join(FLAGS)

XCCONFIG_ASSIGN = re.compile(
    rf"^({FLAG_GROUP})(?:\[[^\]]+\])?\s*=\s*(.*)$",
    re.IGNORECASE,
)
PLIST_VALUE = re.compile(
    rf"<key>\s*({FLAG_GROUP})\s*</key>\s*"
    rf"(?:<true\s*/>|<string>\s*([^<]*?)\s*</string>|<integer>\s*(\d+)\s*</integer>)",
    re.IGNORECASE | re.DOTALL,
)
YAML_ASSIGN = re.compile(
    rf"^({FLAG_GROUP})\s*:\s*(.+)$",
    re.IGNORECASE,
)


def repo_root() -> Path:
    try:
        raw = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            text=True,
        )
        return Path(raw.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return Path(__file__).resolve().parent.parent


def tracked_relpaths(root: Path) -> list[str]:
    raw = subprocess.check_output(
        [
            "git",
            "ls-files",
            "-z",
            "--",
            "*.xcconfig",
            "*Info.plist",
            "*.plist",
            "ios/project.yml",
        ],
        cwd=root,
        text=True,
    )
    return [rel for rel in raw.split("\0") if rel]


def strip_xcconfig_comment(line: str) -> str:
    in_quotes = False
    chars: list[str] = []
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == '"':
            in_quotes = not in_quotes
            chars.append(ch)
            i += 1
            continue
        if not in_quotes and line.startswith("//", i):
            break
        chars.append(ch)
        i += 1
    return "".join(chars).rstrip()


def unwrap_value(raw: str) -> str:
    value = raw.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        value = value[1:-1].strip()
    return value


def is_enabled(raw: str) -> bool:
    return unwrap_value(raw).lower() in ENABLED_VALUES


def check_xcconfig(relpath: str, text: str) -> list[str]:
    hits: list[str] = []
    for lineno, line in enumerate(text.splitlines(), 1):
        stripped = strip_xcconfig_comment(line).strip()
        if not stripped:
            continue
        match = XCCONFIG_ASSIGN.match(stripped)
        if match and is_enabled(match.group(2)):
            hits.append(
                f"{relpath}:{lineno}: {match.group(1)} is {unwrap_value(match.group(2))}"
            )
    return hits


def check_plist(relpath: str, text: str) -> list[str]:
    hits: list[str] = []
    for match in PLIST_VALUE.finditer(text):
        flag = match.group(1)
        string_value = match.group(2)
        integer_value = match.group(3)
        if string_value is None and integer_value is None:
            hits.append(f"{relpath}: {flag} is <true/>")
            continue
        if integer_value is not None and is_enabled(integer_value):
            hits.append(f"{relpath}: {flag} is {integer_value}")
            continue
        if string_value is not None and is_enabled(string_value):
            hits.append(f"{relpath}: {flag} is {unwrap_value(string_value)}")
    return hits


def check_yaml(relpath: str, text: str) -> list[str]:
    hits: list[str] = []
    for lineno, line in enumerate(text.splitlines(), 1):
        stripped = line.split("#", 1)[0].strip()
        match = YAML_ASSIGN.match(stripped)
        if match and is_enabled(match.group(2).rstrip(",")):
            hits.append(
                f"{relpath}:{lineno}: {match.group(1)} is {unwrap_value(match.group(2).rstrip(','))}"
            )
    return hits


def check_file(relpath: str, text: str) -> list[str]:
    suffix = Path(relpath).suffix.lower()
    name = Path(relpath).name
    if suffix == ".xcconfig":
        return check_xcconfig(relpath, text)
    if suffix == ".plist" or name.endswith("Info.plist"):
        return check_plist(relpath, text)
    if name == "project.yml":
        return check_yaml(relpath, text)
    return []


def main() -> int:
    root = repo_root()
    hits: list[str] = []
    scanned = 0
    for relpath in tracked_relpaths(root):
        path = root / relpath
        if not path.is_file():
            continue
        scanned += 1
        hits.extend(check_file(relpath, path.read_text(encoding="utf-8")))

    if hits:
        print(
            "Third-party sign-in must not ship enabled. "
            "Set GROK_SIGN_IN_ENABLED and CHATGPT_SIGN_IN_ENABLED to NO "
            "(or omit them) in committed xcconfig / Info.plist defaults:",
            file=sys.stderr,
        )
        for hit in hits:
            print(hit, file=sys.stderr)
        return 1

    print(
        f"OK: scanned {scanned} committed xcconfig/plist/project.yml file(s); "
        "GROK_SIGN_IN_ENABLED and CHATGPT_SIGN_IN_ENABLED are not YES."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
