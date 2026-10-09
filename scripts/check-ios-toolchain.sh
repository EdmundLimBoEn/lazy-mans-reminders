#!/usr/bin/env bash
set -euo pipefail
version="$(xcodebuild -version)"
printf '%s\n' "${version}"
xcode-select -p
xcodebuild -showsdks
python3 - "${version}" "$(xcrun --sdk iphoneos --show-sdk-version)" "$(xcode-select -p)" <<'PY'
import sys
version, sdk, developer_dir = sys.argv[1:]
if version.splitlines()[0] != 'Xcode 26.6' or 'beta' in developer_dir.lower():
    sys.exit('::error::Release CI requires stable Xcode 26.6')
if int(sdk.split('.')[0]) < 26:
    sys.exit('::error::App Store Connect requires iOS SDK 26 or later')
PY
