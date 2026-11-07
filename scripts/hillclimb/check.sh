#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
: "${HILLCLIMB_UDID:?Use the regular iPhone 17 Pro UUID handed over by the parent}"
python3 - "$HILLCLIMB_UDID" <<'PY'
import json, subprocess, sys
inventory = json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))
for runtime, devices in inventory['devices'].items():
    for device in devices:
        if device['udid'] == sys.argv[1]:
            if device.get('deviceTypeIdentifier') != 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro' or not runtime.endswith('iOS-26-2'):
                sys.exit('Requires regular iPhone 17 Pro on iOS 26.2; Duo/27.1 rejected')
            sys.exit(0)
sys.exit('Requested device unavailable')
PY
cd "$root"
"$root/scripts/ios-generate-project.sh"
xcodebuild test -project ios/LazyMansReminders.xcodeproj -scheme LazyMansReminders \
  -configuration Debug -destination "platform=iOS Simulator,id=$HILLCLIMB_UDID" \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 180 \
  -parallel-testing-enabled NO -resultBundlePath "${HILLCLIMB_RESULT:?Choose a fresh xcresult path}" \
  CODE_SIGNING_ALLOWED=NO
