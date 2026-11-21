#!/usr/bin/env bash
set -euo pipefail
xcodebuild test -project ios/LazyMansReminders.xcodeproj -scheme LazyMansReminders \
 -configuration Debug -destination 'platform=iOS Simulator,id=066ECE57-46B4-414A-B53E-523775329360' \
 -derivedDataPath /tmp/hillclimb-board-dd -parallel-testing-enabled NO \
 -test-timeouts-enabled YES -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 180 \
 -resultBundlePath "$1" "${@:2}" CODE_SIGNING_ALLOWED=NO 2>&1 | \
 rg --line-buffered 'Test Case|error:|failed|passed|notification|Test Suite|TEST (SUCCEEDED|FAILED)|Executed|Swipe|Wait for .*idle'
