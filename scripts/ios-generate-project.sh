#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/ios"
if [ ! -f Config.xcconfig ]; then
  echo "::error::ios/Config.xcconfig is missing. Copy ios/Config.example.xcconfig to ios/Config.xcconfig and set DEVELOPMENT_TEAM."
  exit 1
fi
xcodegen generate --spec project.yml
python3 "$root/scripts/check-ios-target-membership.py" --require-pbxproj
