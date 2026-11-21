# Board edge and accessibility candidate

Implementation commit: `0265cb4aa84c86575ed630633ba835c416eb4de7` on `t3/board-accessibility-contrast`, based on `3b1eb2bdafed24274ff29c70131499ac303a52aa`. Final full-suite validation passed287/287:263 unit and24 UI, zero failures/skips. The original285-test baseline is retained and passed.

Changed production files: ReminderListView.swift, ReorderableReminderList.swift, HillclimbGeometry.swift. Test files: BoardMultilineUITests.swift and new BoardEdgeAccessibilityUITests.swift. Existing HillclimbUITests.swift and its final-row assertions remain unchanged. No SignIn, Account, Activity, global demo, root state, decisions or report files were edited.

The public hosting-controller scroll-view binding was investigated and retained, but its native probe still produced the crisp fragment. The effective fallback is a top-only24pt mask during scrolling, absent at fresh top and pull. No offset, row sizing, physical completion target or bottom fade changes. Reduce Transparency or Increase Contrast selects a6pt opaque boundary rather than blended ink. This deliberately has a harder visual boundary; it is not equivalent to Apple's native glass/blur.

Reminder Text is hidden from accessibility outside its full measured subtree, and the row's `.contain` wrapper is removed. The circle retains the full label, state, hint and Complete action; the reorder leaf and actions remain. Circle-only physical completion, paragraph-tap noncompletion and reorder behavior passed the four-variant focused test. The original positive backing-text existence assertion remains, with stronger pixel/geometry proof and a non-hittable assertion. Separate native AX snapshots reject static paragraph leaves and duplicate full-label completion buttons.

Loading and full-screen error descriptions use explicit primary ink. Every existing literal production word is retained; the only new literals are debug geometry keys. Raw error wording, retry and announcement paths remain unchanged.

## Native evidence

`captures/` contains36 actual device PNGs: normal/populated-error top+bottom, loading/fullscreen error, and completion before/text-tap/circle-edge, both appearances and default/XXXL. `captures-solid/` contains24 more with actual Reduce Transparency and Increase Contrast On. All are1206×2622 originals. Every capture has geometry and native AX JSON; operations retain the owned pinned command, timestamps and exits. No unit renders or derived contact sheets count toward these60 captures.

`matrix-summary.json`, `raster-results.json` and `ax-results.json` establish:

- 16 diagnostic cases: solid normal-text ink21:1 against the actual white/black background.
- 16 bottom cases: complete final-row geometry above composer; final-line strong ink at least2569 pixels.
- 16 fresh-top cases: first paragraph allocated at its full ideal height, fully visible and contrast21:1.
- 16 bottom top-bands: zero pixels above3:1 in the first14 native pixel rows relative to exported viewport geometry; maximum contrast1.6143:1.
- 60 native AX snapshots: no static paragraph leaf, unique complete buttons and one reorder leaf for each visible reminder. No spoken VoiceOver pass is claimed.

`native-binding-comparison.json` compares the matched default original probe and final capture:1260 strong pixels become0;1084 matched opaque-glyph samples yield effective alpha0.0452–0.1781. The binding-only failed original and its source/binary/xctestrun hashes are retained.

All60 manual originals were inspected, with the closest Apple references from reference/round3 for XXXL and older default light/dark lists. Native Apple chrome softens content under its bar; our viewport begins below its inset. References have different paragraphs and controls. No exact Apple error/loading or Notes counterpart is available.

Settings original, enabled and restored PNG/JSON prove both switches Off → On → Off. `settings-operations.json` records restoration of light/Large. Reduce Motion was not changed. Combined-setting board/diagnostic evidence does not certify spoken VoiceOver, AX1–AX5 or physical haptics/locked-device behavior.

## Build and checks

Fresh owned DerivedData: `/tmp/notepad-board-edge-L-dd`. Own setup.sh/example-derived configuration uses systems.edmundlim.NotepadHillclimb and its group. Builds use unsigned arm64 Debug build-for-testing, assigned regular iPhone17Pro/iOS26.2 UDID066ECE57-46B4-414A-B53E-523775329360, disabled automatic package resolution and skipped package updates after setup. xcodegen was rerun after adding the dedicated tests. The generated xctestrun filename names SDK27.1; actual destination evidence is regular iPhone17Pro/iOS26.2/23C54.

The final full suite uses the exact generated xctestrun, parallel NO, diagnostics never, timeouts180/240 and no filters/skips. Actual final summary and test-name verification confirm287 passed,0 failed,0 skipped, with all285 existing test IDs retained. The23 offline iOS Python checks passed. Source, app/widget/runner/test binary and generated-xctestrun hashes are in build-capture-inputs.json; final-inputs.json records full-suite source inputs. `architecture.json` verifies arm64.

The first full run selected287, passed286 and failed1, zero skips: the first duplicate-static-text gate. The modifier-order-only correction did not resolve the focused gate. One focused execution also reported an older assertion than the current built binary; explicit app/runner installation was then used. The `.contain` removal resolved the four-variant focused test. All failed results and native attachments are retained; no unchanged failed test was simply retried until green.

Initial clean compilation retained pre-existing AuthManager weak-capture/unused-result, AuthSessionGateTests unused/unreachable-code and AppIntents metadata-extraction warnings. Later builds retain the metadata warning where emitted. XCTest launcher debugger lookup messages, unsigned APNs and IOSurface diagnostics are retained. Final scoped runtime issues are0 warnings and0 invalid-frame events;9242 other error/fault events are retained. This is not a globally clean-log claim.

Written by gpt-6.1-sol in Codex on behalf of Edmund


## Final handoff

`acceptance.json` independently verifies the exact old285 test IDs remain present and passed, plus the2 new UI tests. Final result:287/287,263 unit+24 UI, no failures or skips. `final-process.json` records the exact command and exit0. The generated xctestrun hash is b7987a593438f96e6b49a823cc29004706492422cbd8747ebbeb03c8de2e6764. App, widget, runner/test binaries and all Swift source hashes are retained in build-capture-inputs.json and key-hashes.json.

The final full suite also exported84 actual native UI-test PNGs:40 edge/diagnostic,40 existing board matrix and4 original last-row-ink captures. These are separate from the60 manual captures and all earlier failed-attempt artifacts. Unit-rendered Activity images are not exported or counted here.

Cleanup: both accessibility switches restored Off, light/Large restored again after the suite, app relaunched in the inert empty/default fixture then closed, owned exact demo Activity IDs empty before and after cleanup. No broad Activity ending occurred. The owned pinned session and Device panel were closed without shutdown; the regular17 simulator remains running. Other devices/sessions/artifacts/caches were not touched. Only Python bytecode files generated by this task were removed from the otherwise clean worktree.

No score assigned. No physical haptics, spoken VoiceOver or true locked-device certification. The harder opaque edge under Reduce Transparency/Increase Contrast and the XCUITest hidden backing-node distinction remain explicit. Raw wording approval is still pending. Parent should merge only after reviewing this candidate, then rebuild/capture/regrade on original17 for round5.

No push, PR, main merge, force push, deployment, TestFlight/AppStore, live auth/service/data writes or external messages were performed.

Written by gpt-6.1-sol in Codex on behalf of Edmund
