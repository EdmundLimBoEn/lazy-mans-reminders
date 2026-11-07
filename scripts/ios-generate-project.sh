#!/usr/bin/env bash
# Generate LazyMansReminders.xcodeproj from ios/project.yml and check
# that app and widget Compile Sources include the shared session files.
# Requires ios/Config.xcconfig. Device and simulator builds both use this project.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/ios"
if [ ! -f Config.xcconfig ]; then
  echo "::error::ios/Config.xcconfig is missing. Copy ios/Config.example.xcconfig to ios/Config.xcconfig and set DEVELOPMENT_TEAM."
  exit 1
fi
xcodegen generate --spec project.yml
python3 "$root/scripts/check-ios-target-membership.py" --require-pbxproj
