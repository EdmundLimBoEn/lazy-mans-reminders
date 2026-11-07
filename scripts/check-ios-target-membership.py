#!/usr/bin/env python3
"""Check that app and widget XcodeGen sources compile the shared session files."""

from __future__ import annotations

import argparse
import fnmatch
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBXPROJ_PATH = ROOT / "ios/LazyMansReminders.xcodeproj/project.pbxproj"
APP_TARGET = "LazyMansReminders"
WIDGET_TARGET = "ReminderWidgetExtension"
REQUIRED_TYPES = (
    "SessionCredentialStorage",
    "KeychainSessionStorage",
    "SharedSessionStorage",
)

TARGET_SPLIT = re.compile(r"\n  (?=\S)")
SHARED_DIRECTORY = re.compile(
    r"^      - path: Shared\n((?:        .*\n)*)",
    re.MULTILINE,
)
LIST_ITEM = re.compile(r"^          - (.+)$", re.MULTILINE)
TARGET_NAME = re.compile(r"name = ([^;]+);")
SOURCES_PHASE = re.compile(r"([A-F0-9]+) /\* Sources \*/")
SOURCES_FILES = re.compile(
    r"([A-F0-9]+) /\* Sources \*/ = \{.*?files = \((.*?)\);",
    re.DOTALL,
)
SWIFT_IN_SOURCES = re.compile(r"/\* (\S+\.swift) in Sources \*/")
TYPE_DEFINITION = re.compile(
    r"^(?:public |internal |private |fileprivate )*"
    r"(?:protocol|struct|class|enum|actor|typealias) (\w+)",
    re.MULTILINE,
)


def repo_root(start: Path | None = None) -> Path:
    return start or ROOT


def target_section(spec: str, target: str) -> str:
    marker = f"\n  {target}:\n"
    if marker not in spec:
        raise ValueError(f"ios/project.yml is missing target {target}")
    return TARGET_SPLIT.split(spec.split(marker, 1)[1], 1)[0]


def parse_list(block: str, key: str) -> list[str]:
    match = re.search(rf"^        {key}:\n((?:          .*\n)*)", block, re.MULTILINE)
    if not match:
        return []
    return [item.strip().strip("\"'") for item in LIST_ITEM.findall(match.group(1))]


def shared_source_blocks(section: str) -> list[str]:
    return [match.group(1) for match in SHARED_DIRECTORY.finditer(section)]


def shared_swift_from_spec(spec: str, target: str, shared_files: list[str]) -> set[str]:
    blocks = shared_source_blocks(target_section(spec, target))
    if not blocks:
        raise ValueError(f"{target} does not include path: Shared")
    included: set[str] = set()
    for block in blocks:
        includes = parse_list(block, "includes")
        excludes = parse_list(block, "excludes")
        for name in shared_files:
            if includes and not any(fnmatch.fnmatch(name, pattern) for pattern in includes):
                continue
            if any(fnmatch.fnmatch(name, pattern) for pattern in excludes):
                continue
            included.add(name)
    return included


def defined_types(source: str) -> set[str]:
    return set(TYPE_DEFINITION.findall(source))


def pbxproj_swift_sources(pbxproj: str, target: str) -> set[str]:
    for chunk in pbxproj.split("isa = PBXNativeTarget;")[1:]:
        name_match = TARGET_NAME.search(chunk)
        if name_match is None:
            continue
        name = name_match.group(1).strip().strip('"')
        if name != target:
            continue
        phases = re.search(r"buildPhases = \(\s*(.*?)\s*\);", chunk, re.DOTALL)
        if phases is None:
            raise ValueError(f"{target} has no buildPhases")
        phase_match = SOURCES_PHASE.search(phases.group(1))
        if phase_match is None:
            raise ValueError(f"{target} has no Sources build phase")
        phase_id = phase_match.group(1)
        for found_id, files in SOURCES_FILES.findall(pbxproj):
            if found_id == phase_id:
                return set(SWIFT_IN_SOURCES.findall(files))
        raise ValueError(f"{target} Sources phase {phase_id} is missing")
    raise ValueError(f"pbxproj is missing target {target}")


def check_spec(root: Path | None = None) -> list[str]:
    root = repo_root(root)
    spec = (root / "ios/project.yml").read_text(encoding="utf-8")
    shared_files = sorted(path.name for path in (root / "ios/Shared").glob("*.swift"))
    if "SharedSessionStorage.swift" not in shared_files:
        return ["ios/Shared/SharedSessionStorage.swift is missing"]
    storage = defined_types(
        (root / "ios/Shared/SharedSessionStorage.swift").read_text(encoding="utf-8")
    )
    errors = [f"ios/Shared/SharedSessionStorage.swift does not define {name}"
              for name in REQUIRED_TYPES if name not in storage]
    store = (root / "ios/Shared/ReminderStore.swift").read_text(encoding="utf-8")
    for name in REQUIRED_TYPES:
        if name not in store:
            errors.append(f"ios/Shared/ReminderStore.swift does not use {name}")
    for target in (APP_TARGET, WIDGET_TARGET):
        included = shared_swift_from_spec(spec, target, shared_files)
        missing = [name for name in shared_files if name not in included]
        if missing:
            errors.append(f"{target} omits Shared Swift files: {', '.join(missing)}")
    return errors


def check_pbxproj(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []
    required = {"SharedSessionStorage.swift", "ReminderStore.swift"}
    for target in (APP_TARGET, WIDGET_TARGET):
        try:
            sources = pbxproj_swift_sources(text, target)
        except ValueError as exc:
            errors.append(str(exc))
            continue
        missing = sorted(required - sources)
        if missing:
            errors.append(f"{target} Compile Sources omit {', '.join(missing)}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-pbxproj", action="store_true")
    parser.add_argument("--pbxproj", type=Path, default=PBXPROJ_PATH)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)
    errors = check_spec(args.root)
    pbxproj = args.pbxproj
    if pbxproj.is_file():
        errors.extend(check_pbxproj(pbxproj))
    elif args.require_pbxproj:
        errors.append(f"{pbxproj} is missing. Run xcodegen generate first.")
    if errors:
        print("iOS target membership check failed:", file=sys.stderr)
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(
        "OK: app and widget compile SharedSessionStorage.swift "
        "(SessionCredentialStorage, SharedSessionStorage)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
