#!/usr/bin/env bash
set -euo pipefail
version="$(xcodebuild -version)"
printf '%s\n' "${version}"
xcode-select -p
xcodebuild -showsdks
python3 - "${version}" "$(xcrun --sdk iphoneos --show-sdk-version)" "$(xcode-select -p)" <<'PY'
import sys
version, sdk, developer_dir = sys.argv[1:]
lines = version.splitlines()
build = lines[1].removeprefix('Build version ').strip() if len(lines) > 1 else ''
if lines[0] != 'Xcode 27.1' or build != '27A9275' or 'beta' in developer_dir.lower():
    sys.exit('::error::Release CI requires stable Xcode 27.1 (27A9275)')
if sdk != '27.1':
    sys.exit(f'::error::Release CI requires the iOS 27.1 SDK, got {sdk}')
PY
