# Offline capture harness

Base: `hillclimb/ui` at `471a46b`. Branch: `hillclimb/capture-harness`.
This preparatory change adds fixtures and measurement only. Geometry gates must
be run on a regular **iPhone 17 Pro, iOS 26.2**. No Duo or 27.1 fallback.

## Isolation and fixtures

Run `scripts/hillclimb/setup.sh` in this worktree. It derives an ignored config
from the checked-in example, uses `systems.edmundlim.NotepadHillclimb` and
`group.systems.edmundlim.NotepadHillclimb`, and refuses to overwrite another
config. It never reads the parent's ignored config. Demo auth fails fast unless
this isolated App Group is configured.

Only Debug recognizes `--hillclimb-demo STATE`. States: `full`, `empty`,
`composer`, `account`, `signin`, `long-text`. Add `--hillclimb-style light|dark`
and `--hillclimb-size default|XXXL`. XXXL means the system `.xxxLarge` category,
not the largest accessibility category. The DEBUG export view also sets the
window's UIKit content-size trait so UICollectionView UIHostingConfiguration rows
receive the same size. Tests compare the actual UIKit preferred font against the
system large-category font. Launch each state afresh.

Fixtures use stable UUIDs and timestamps, explicitly marked Demo text, and exactly
`ReminderBoardLimits.maxActive` rows for the full and long-text boards. Long rows
create overflow without exceeding capacity. Composer starts empty and focusable;
its keyboard is opened by the capture operation. Account uses the production
medium/large sheet over a seeded board. Account/sign-in retain real copy and are
read-only; no fabricated authenticated identity is installed.

The demo-only AuthManager initializer returns before restoration, credential
observers or background tasks. Its client has empty nonpersistent auth storage,
a failing auth fetch closure, an ephemeral URLSession with a rejecting URLProtocol,
and an invalid server URL. The Debug delegate router never constructs the real
AppDelegate during demo launches. URL callbacks and background scheduling are
blocked. Board refresh, completion, create and reorder never enter the real store.
AppStorage uses a dedicated reset demo suite. No demo seeds are written to the
shared store or to Live Activities. Normal Debug and Release paths remain live.

## Build and tests

```
scripts/hillclimb/setup.sh
xcodebuild build-for-testing -project ios/LazyMansReminders.xcodeproj \
  -scheme LazyMansReminders -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/notepad-hillclimb-derived CODE_SIGNING_ALLOWED=NO
```

After the parent hands over the device:

```
HILLCLIMB_UDID='<handed-over UUID>' HILLCLIMB_RESULT='/tmp/hillclimb-unique.xcresult' \
  scripts/hillclimb/check.sh
```

This runs BOTH `LazyMansRemindersTests` and `HillclimbUITests`, without parallel
simulator clones. The script rejects the wrong device/runtime. Tests use the
project test runner, which is authorized separately from capture interaction.
Do not run while the parent is driving reference apps.

The UI tests read actual SwiftUI global frames through a DEBUG-only accessibility
probe. Assertions compare last-row bounds to composer and window safe-area bounds
after top pull and bottom scroll, compare actual text height to a hidden intrinsic
SwiftUI text measurement at the same width/font/kerning, and compare actual control
frames to 44pt. They include the keyboard dismiss target and auth state/fixture
stability. Measurement text is hidden and never used as screenshot content.
No source scans establish geometry. Large rows that cannot fully fit are failures,
not silently exempted. Screenshot review still needs to assess typography and
clipping visually. The probes do not measure Island hardware directly; window
safe-area bounds establish the non-overlap boundary.

## Actual captures

1. After device handover, call T3 `device_list`, then `device_open` with `hostId:
   local` and the handed-over regular device id. Save its returned **device
   object** as a JSON file. Use its exact `agentDevice.command` including session.
2. Run that pinned command's `help open`, `help screenshot`, and gesture/close
   help. The executable/session are supplied by T3, not assumed to be on PATH.
3. Transcribe the documented arguments into an operations JSON file. Each value
   is an argv array appended to that command, with no shell evaluation:
   - `open`: open/relaunch the isolated installed app with explicit launch args;
     include `{state}`, `{style}`, `{size}` in the matching hillclimb arguments.
     It must terminate/relaunch, not merely foreground the previous fixture.
   - `screenshot`: use the real screenshot command and `{path}` for its PNG output.
   - `pull`: downward pull on the list at the top, away from the reorder grip.
   - `bottom`: upward scroll on the list; repeated 20 times to reach its bottom.
   - `focus`: tap the real New reminder field for the composer keyboard capture.
   - `close`: terminate the fixture app. Do not close anyone else's session.
   Command syntax is intentionally not guessed before a pinned session is available.
4. Install the Debug app with `xcrun simctl install` (allowed). All launch, input,
   scrolling and screenshots use the pinned command, never simctl UI commands.
5. Run:

```
scripts/hillclimb/shots.sh --round 1 --device /tmp/hillclimb-device.json \
  --command '<exact T3-returned pinned command>' \
  --operations /tmp/hillclimb-operations.json
```

6. Call T3 `device_screenshot` and inspect the actual device. Inspect captured PNGs
   too. Record unexpected states and rerun with a fresh round rather than replacing
   evidence. No screenshots have been generated or inspected yet.

The script captures light/dark full, empty, composer, account, sign-in, long text,
full bottom-after-pull and XXXL long text top/bottom-after-pull. It requires a fresh
`hillclimb/rounds/<n>/`, saves actual PNGs, hashes, source SHA, dirty flag, device,
operation templates and per-capture status in `manifest.json`. Failures remain
in the manifest. Live Activity is explicitly unavailable: this safety fixture
does not start ActivityKit or seed shared storage. It must not be represented as
observed native Live Activity evidence. Parent supplies paired Apple references.

## Evidence recorded 2026-11-04

- XcodeGen installed at `/opt/homebrew/bin/xcodegen`; generation succeeded.
- Debug generic simulator `build-for-testing`: passed with SDK 27.1, arm64 and
  x86_64. Includes existing unit tests and the new UI test bundle; **compilation
  is not test execution**. Derived data `/tmp/notepad-hillclimb-derived`.
- Release generic simulator `build`: passed with `CODE_SIGNING_ALLOWED=NO`.
- `python3 -m unittest discover -s scripts/tests -p 'test_ios*.py'`: 23 passed.
- Bash syntax and `shots.sh --help`: passed.
- `xcrun simctl list runtimes`: only iOS 27.1 installed at inspection time.
- Standard17 runtime tests, geometry results, app screenshots, pinned operation
  templates and device inspection: **pending runtime installation and parent
  handover**. No shared device UI interaction performed. A local unpinned
  `agent-device help` lookup returned command not found; no device was controlled.
- Potential baseline finding, source-derived/unobserved: keyboard dismiss uses a
  32pt-wide frame; the new 44pt gate may fail. No visual fix or assertion weakening
  was applied. Report actual failures to PM after running the tests.

Build evidence above was gathered on the task worktree based on `471a46b` with
changes uncommitted; the delivered commit SHA is reported in the implementation
handoff. No PR, push, merge, deployment or TestFlight action is part of this task.

Written by gpt-6.1-sol in Codex on behalf of Edmund
