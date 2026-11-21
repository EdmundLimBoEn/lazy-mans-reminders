#!/usr/bin/env bash
# Written by gpt-6.1-sol in Codex on behalf of Edmund
set -euo pipefail
agent=/Users/limboenedmund/.t3/userdata/device/targets/t3-d375faee8af31d01dd89e9c3/agent-device
app=/tmp/notepad-round3-original17-dd/Build/Products/Debug-iphonesimulator/LazyMansReminders.app
xcrun simctl install 78F5A64F-7B2E-4562-8EF9-10F3312CC694 "$app"
"$agent" open systems.edmundlim.NotepadHillclimb --relaunch --launch-args=--hillclimb-demo --launch-args=empty
"$agent" settings appearance light
"$agent" settings text-size large
scripts/hillclimb/shots.sh --round 3 --device hillclimb/validation/round3/device.json --command "$agent" --operations scripts/hillclimb/operations.example.json
