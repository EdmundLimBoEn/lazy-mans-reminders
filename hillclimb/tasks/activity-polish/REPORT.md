# Activity polish handback

Branch: `hillclimb/activity-polish`. Base: `273dd42`. Implementation: `dcc4200e4b59a87ad66b0ebf0cc51da086c719bb`. Evidence is committed separately. No PR, push, merge, deployment or production writes.

The assigned regular iPhone 17 Pro / iOS 26.2 (`78F5A64F-7B2E-4562-8EF9-10F3312CC694`, local) rendered an actual Activity requested with ActivityKit, `pushType: nil`, synthetic lines and the isolated example bundle/group. The Debug helper refuses other bundle/group IDs and records only its own Activity IDs for cleanup. It uses no shared production board store or network. Normal launches keep their existing path.

The first native recording exposed a cropped plus sign at the Island's rounded lower-left corner. `island-native.mp4` / `island-video-frame.png` retain that intermediate-candidate evidence (already had initial scalable layout changes; these are NOT baseline screenshots). Native footer x was 17.7pt. Final implementation adds 14pt horizontal inset and increases Island bottom clearance from 14pt to 20pt. The native regression now measures x=45.7pt, height=18pt at default and 23.7pt at XXXL, bottom=131.7pt and 128.7pt respectively. See native-frame-*.txt and the two native test summaries.

Lock Screen fixed 15pt type becomes scalable subheadline-relative type. Separate presentation budgets reserve 134pt for banner rows inside 26pt padding and 96pt for expanded Island rows below its sensor region. This follows Apple's possible 160pt truncation limit: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities. The shared view uses measured font line heights, single-line tail truncation and the existing `+N more` wording for hidden payload rows. At default, the banner renders six rows and Island four; at XXXL, five and three. Long rows intentionally truncate horizontally. Fewer rows at larger sizes and a narrower Island text column are the tradeoffs for complete last-row ink. Board capacity, its cache calculation, payload schema, storage and sync are unchanged. The existing Island XXXL scaling cap remains.

Files changed:

- ios/Widget/ReminderLiveActivity.swift
- ios/Shared/LockScreenLineBudget.swift
- ios/Shared/ReminderAttributes.swift
- ios/App/HillclimbDemo.swift
- NEW ios/App/HillclimbActivityDemo.swift
- NEW ios/Tests/ActivityLayoutTests.swift
- NEW ios/UITests/ActivityNativeLayoutTests.swift
- NEW scripts/hillclimb/activity-evidence.py
- This task's evidence directory only.

Validation:

- `scripts/hillclimb/setup.sh`, `xcodegen generate --spec ios/project.yml`: completed using this worktree's example config.
- `xcodebuild -project ios/LazyMansReminders.xcodeproj -scheme LazyMansReminders -configuration Debug -destination 'platform=iOS Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694' -derivedDataPath /tmp/hillclimb-activity-dd CODE_SIGNING_ALLOWED=NO build`: BUILD SUCCEEDED.
- Same configuration with `-only-testing:LazyMansRemindersTests test -resultBundlePath /tmp/hillclimb-activity-final.xcresult`: 249 executed, 249 passed, zero skipped/failed. Includes 247 baseline tests and two Activity tests. The rendered test checks twelve actual SwiftUI rasters for height and every glyph band, including the last row, across light/dark, default/XXXL/accessibility5 and both surfaces. `rendered-unit/` contains those test images; these are explicitly unit-renderer artifacts, not native surface evidence.
- Same configuration with `-only-testing:HillclimbUITests/ActivityNativeLayoutTests/testExpandedIslandLastLineClearsRoundedCorners test`: one executed, one passed at default (`/tmp/hillclimb-activity-native-default.xcresult`), then one executed, one passed after the pinned command set system XXXL (`/tmp/hillclimb-activity-native-XXXL.xcresult`). Checks real SpringBoard Activity footer frames against corner/height bounds. No zero-selection success claims.
- An initial test invocation failed at compile time because the project was generated before the new helper existed. Regeneration resolved it; subsequent unit/UI runs above executed successfully.

Native evidence:

- `manifest.json` contains exact pinned commands, operation output, source SHA, device and SHA-256 hashes. Matrix: light/dark × default/XXXL × short/long × collapsed/expanded/Notification Center = 24 final PNGs, plus eight expanded recordings. Captures occurred after actual build/install. The second banner pass removed the OS permission prompt by accepting Always Allow for the isolated demo app.
- Expanded PNGs are unmodified frames at 2 seconds from device-scope recordings through the pinned command. Still screenshots omit the Island overlay on this simulator, even while SpringBoard AX exposes the real Activity. Video solves expanded evidence; collapsed stills show the home/status area, but do not establish the hardware cutout's exact pixel geometry. Compact/minimal content remains empty as before.
- Notification Center shows the actual native banner, with fully visible final overflow row at both sizes and appearances. It is the shared Lock Screen presentation, but no actual locked-device state was reached: pinned `help hardware-button` explicitly refuses iOS simulator sleep/power. No invented lock command or replica was used.
- Final XXXL long-text banner and Island images were visually inspected in both appearances; default native Island and banner images were also inspected. White Island text remains clear on black. The clear banner uses native wallpaper material; arbitrary wallpapers and increased-contrast/Reduce Transparency settings remain unverified. No new score is assigned.

Unrelated baseline UI results are retained as failures, not weakened or rerun by this worker:

- `testComposerKeyboardDismissTarget`: New reminder 22pt height vs 44pt.
- `testFullBoardBottomAboveComposerAfterPullAndScroll`: two-minute execution allowance exceeded.
- `testTopControlsAvoidIslandAndHave44PointTargets`: Account 36pt width vs 44pt.
- Historical `testOfflineRoutesAndFixtureStability` failed on XCTest's 128-character query limit; the supplied later repaired fixture run passed one test. That historical failure is resolved only by that recorded follow-up, not by this worker's Activity checks.
- Baseline faded board final-row ink remains outside this task's ownership. Nothing here claims the board UI gates pass.

Cleanup ends only persisted demo-owned Activity IDs via explicit `--hillclimb-demo activity --hillclimb-activity end`, returns appearance/type to light/default, and closes this task's app/session. Reference Reminders data and unrelated local data remain untouched. Parent must re-shoot and regrade after integration on original17.

Written by gpt-6.1-sol in Codex on behalf of Edmund
