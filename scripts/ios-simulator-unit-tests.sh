#!/usr/bin/env bash
# Build LazyMansRemindersTests on an available iPhone simulator.
# Used by ios-tests.yml and by ios-testflight.yml before archive.
# Needs no signing secrets: ad-hoc simulator identity, CODE_SIGNING_ALLOWED=NO.
# IOS_TEST_TARGETS (space-separated) overrides the test targets; the default
# is LazyMansRemindersTests so the TestFlight pre-archive gate is unchanged.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}/ios"

if [ ! -d LazyMansReminders.xcodeproj ]; then
  echo "::error::LazyMansReminders.xcodeproj is missing. Run xcodegen generate first."
  exit 1
fi

udid="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    if "iOS" not in runtime:
        continue
    for device in devices[runtime]:
        if device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
sys.exit("No available iPhone simulator")
')"

echo "Using iPhone simulator ${udid}"

result_bundle="${RESULT_BUNDLE_PATH:-${RUNNER_TEMP:-/tmp}/ios.xcresult}"
rm -rf "${result_bundle}"

only_testing=()
for target in ${IOS_TEST_TARGETS:-LazyMansRemindersTests}; do
  only_testing+=("-only-testing:${target}")
done
echo "Testing: ${only_testing[*]}"

xcodebuild test \
  -project LazyMansReminders.xcodeproj \
  -scheme LazyMansReminders \
  -destination "platform=iOS Simulator,id=${udid}" \
  -resultBundlePath "${result_bundle}" \
  "${only_testing[@]}" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= \
  CODE_SIGNING_ALLOWED=NO
