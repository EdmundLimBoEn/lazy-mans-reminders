#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="${RUNNER_TEMP:-/tmp}/lmr-release-derived-data"
cd "${root}/ios"
xcodebuild build \
  -project LazyMansReminders.xcodeproj \
  -scheme LazyMansReminders \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${derived_data}" \
  CODE_SIGNING_ALLOWED=NO
python3 "${root}/scripts/validate-ios-release.py" \
  "${derived_data}/Build/Products/Release-iphoneos/LazyMansReminders.app" \
  --output "${RUNNER_TEMP:-/tmp}/ios-release-metadata.json"
