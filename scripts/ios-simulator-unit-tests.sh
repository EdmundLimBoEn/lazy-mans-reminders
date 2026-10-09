#!/usr/bin/env bash
# Build LazyMansRemindersTests on an available iPhone simulator.
# Used by ios-tests.yml and by ios-testflight.yml before archive.
# Needs no signing secrets: ad-hoc simulator identity, CODE_SIGNING_ALLOWED=NO.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}/ios"

if [ ! -d LazyMansReminders.xcodeproj ]; then
  echo "::error::LazyMansReminders.xcodeproj is missing. Run xcodegen generate first."
  exit 1
fi

sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
udid="$(xcrun simctl list devices available --json | python3 "${root}/scripts/select-ios-simulator.py" "${sdk_version}")"

echo "Using iPhone simulator ${udid}"

result_bundle="${RESULT_BUNDLE_PATH:-${RUNNER_TEMP:-/tmp}/ios.xcresult}"
if [ -e "${result_bundle}" ]; then
  echo "::error::Result bundle already exists: ${result_bundle}. Choose a fresh RESULT_BUNDLE_PATH."
  exit 1
fi

xcodebuild test \
  -project LazyMansReminders.xcodeproj \
  -scheme LazyMansReminders \
  -configuration "${TEST_CONFIGURATION:-Debug}" \
  -destination "platform=iOS Simulator,id=${udid}" \
  -resultBundlePath "${result_bundle}" \
  -only-testing:LazyMansRemindersTests \
  ENABLE_TESTABILITY=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= \
  CODE_SIGNING_ALLOWED=NO
