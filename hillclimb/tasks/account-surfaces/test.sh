#!/usr/bin/env bash
set -euo pipefail
xcodegen generate --spec ios/project.yml
xcodebuild test -project ios/LazyMansReminders.xcodeproj \
  -scheme LazyMansReminders -configuration Debug \
  -destination 'platform=iOS Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694' \
  -derivedDataPath /tmp/notepad-account-derived CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:LazyMansRemindersTests \
  -only-testing:HillclimbUITests/AccountPresentationTests/testDefaultAccountPresentation \
  -only-testing:HillclimbUITests/AccountPresentationTests/testXXXLAccountPresentation \
  -resultBundlePath "${1:?Pass a new xcresult path}"
