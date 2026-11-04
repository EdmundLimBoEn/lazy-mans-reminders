# Board reading worker evidence

Branch: `hillclimb/board-reading`. Source changes are confined to `ios/App/ReminderListView.swift`, `ios/App/ReorderableReminderList.swift`, `ios/App/HillclimbGeometry.swift`, and `ios/UITests/HillclimbUITests.swift`. Task-local evidence lives here. No parent reports, scores, other worker source, branding, icons, or user-facing wording changed.

## Reviewable changes

- `cc9809880c81309aed14162df87a9584fa7648bb`: remove the 36pt composer gradient and both bottom edge effects; give the populated UIKit list sole refresh ownership; finish refresh on return/cancellation and tear-down; clear loading state with defer. Use a compact native title to preserve context and avoid the pull/large-title animation hang. Add runtime edge-state, text geometry, final-line pixel contrast and dark appearance gates.
- `ef82a67`: expand Account, composer field, and dismiss targets to at least 44pt without changing glyph sizes. Combine the field's accessibility frame with its interactive padding; guard disabled-state focus. Tests tap padded edges and verify Account, keyboard focus/dismissal, and full-board refusal to focus.

## Diagnosis and its limits

The duplicate refresh-owner hypothesis was insufficient: removing outer refreshable still produced the same 60-second “App animations complete notification not received” event and then timed out on the next swipe. Deferring endRefreshing until finger release and resetting the inset without animation also failed with the large navigation title. Switching to the compact native title was the change after which the light/default gate settled in about eight seconds. The final configuration then passed three fresh-process repetitions (10.044s, 6.744s, 6.732s). This isolates a pull/large-title transition interaction in this bridge; it does not establish a specific private UIKit implementation defect. XCTest waiting and the actual top pull remain enabled.

`pull-timeout-activities.json` records the unsuccessful ownership-only attempt; `pull-passed-activities.json` records the successful compact-title run. `lifecycle-timeout-activities.json` records the subsequent failed no-animation completion attempt. These are historical experiments, not final failures. An earlier pixel-count expression failed Swift type checking; that attempt executed no UI tests and was corrected before the recorded runtime experiments. UIRefreshControl cleanup covers normal return, error handled by the callback, cancellation and dismantling in source. Only the offline callback path was exercised on device; live-network success/error/cancel were not exercised.

## Regression contract

`final-test-summary.json` records the final full suite at ef82a67b5628698eaa227610e1b3589acabc7323: 253 executed, 253 passed, 0 failed, 0 skipped (247 existing unit tests plus all 6 board UI tests). No unrelated baseline UI failures remain in this final run. `repeat-summary.json` records the three repetitions of one unique pull test on the earlier `7084fc5` source, before the disabled-focus guard. The summary's unique passedTests is 1; its device-level passedTests is 3. No zero-selected-test result is counted as a pass.

The six board UI tests retain safe-area and actual-versus-intrinsic text-height assertions. Bottom reading additionally checks rendered final-text bounds against the UIKit viewport and actual bottom-edge hidden state, not just the composer. UIKit has no public fade extent API: any reintroduced visible effect conservatively fails the whole viewport. The final 18pt text strip must contain more than 20 near-primary foreground pixels (all RGB channels below 55 in light or above 200 in dark), so gray final glyphs fail. The capture includes no composer or separator in that strip. Test screenshots are attached and exported under `final-test-attachments/`. `test-attachments/` retains the earlier passing 7084fc5 captures.

`test.sh` contains the exact build/test arguments, assigned regular iPhone 17 Pro UDID, single derived-data folder, and CODE_SIGNING_ALLOWED=NO. `commands.json` records executed invocations. The example configuration was created only through `scripts/hillclimb/setup.sh`; the project was generated with XcodeGen. xcodebuild test built and installed the isolated app. A redundant manual install attempt after the repetitions found the simulator shut down; pinned agent-device open subsequently booted and launched the test-installed app.

`capture.py` uses only the exact T3-pinned command for launches, raw pulls/drags, clicks, screenshots and close. It records source SHA and file hashes in `manifest.json`. Captures cover board top and bottom-after-pull in both appearances/default and XXXL, and composer unfocused/keyboard/dismissed in all four combinations. The assigned app/session is closed in its finally block. These private-device shots are verification only; parent grading must re-shoot original17.

## Remaining scope and evidence gaps

SOL-01 and SOL-02 are implemented; the compact title also addresses SOL-04's lost context. Optional SOL-03 first-line control alignment and SOL-07 wrapping the capacity placeholder remain unchanged. The XXXL capacity placeholder still truncates. Setup-tip fragments can still be clipped at the composer when typing; its copy/style is outside this change. This worker does not establish VoiceOver spoken traversal, physical haptics, ActivityKit, accessibility sizes above XXXL, or settings-on Reduced Transparency behavior. No live session or datastore was used, no push/PR/merge/deploy/submission was performed.

Written by gpt-6.1-sol in Codex on behalf of Edmund
