# Notepad UI hill climb

Integration: `hillclimb/ui`, based on origin/main `5fc4cbc`. Work is ongoing; score gate not reached. Never merge main, deploy, submit, force push, or touch Edmund's preexisting untracked files.

## Reviewer and stop rules

- Every round: independent gpt-6.1-sol/high and gpt-6-astra/high reviews of the same screenshots, source, checks and Apple reference pairs;30 detailed categories, honest arithmetic-mean overall.
- Edmund's updated rule: Claude Opus5.5/medium ONLY if BOTH Codex graders score >=8.5 overall in the SAME round. This replaces every-other-round scheduling. Round1 is ineligible; Opus has not run.
- Final stop unchanged: ALL THREE graders >=9 overall and NO category below7. Eligibility at8.5 is not completion.
- Also stop for nearly exhausted Codex quota or3 plateau rounds. No dedicated quota tool is exposed. Current-session rate-limit metadata is available:7% used in a10080-minute window as of2026-11-04T14:39:08.493Z (rounds/2/usage.json); not near exhaustion. No waiting into the next weekly window is authorized.

## Scores

| Round | Sol | Astra | Opus | Evidence |
| --- | ---: | ---: | --- | --- |
|0|Not graded|Not graded|Not due|Setup only|
|1|6.88|6.70|Ineligible|18 app captures,5 usable Reminders references; Notes/native Activity initially missing|
|2|8.11|8.16|Ineligible|Minimum7.0 each;261 combined tests passed;48 native images+4 fresh references|

## Current tasks and ownership

| Task | Status | Scope / evidence |
| --- | --- | --- |
|Capture harness|Merged|Offline isolated Debug modes; real geometry probes; repeatable/resumable captures. Round1 retains failed synthesized-scroll attempt and advised successful raw drag.|
|Apple references|Merged, partial|5 usable Reminders references;4 transition frames excluded; Notes unavailable. pairs.json records gaps.|
|A board-reading|Merged|cc98098/ef82a67/9ff1d6c: no final-ink fade, refresh cleanup, compact title/count, actual44pt field/Account/dismiss targets.253 tests passed (247 unit+6 board UI),3 fresh-process pull repetitions,20 capture hashes verified by parent.|
|B signin-surfaces|Merged with recorded warning|04098b7/96077a3: flatter sections,44pt focus containers and keyboard scrolling.250 tests passed (247 unit+3 dedicated UI),24 settled captures verified. Invalid-frame runtime warning localized to keyboard-matrix test; source not identified.|
|C activity-polish|Merged|dcc4200/de1ad3a: scalable native Activity rows, independent surface budgets and Island corner clearance.249 unit tests+1 native check each at default/XXXL passed;24 actual native captures verified.|
|D account-surfaces|Merged|9f94f55: opaque grouped background, large on open/reopen with medium retained, safe demo scrolling/Done,44pt targets.249 unit+2 dedicated Account UI tests passed;16 hashes verified by parent. Original17 returned clean.|

A returned source ownership before D was authorized to edit caller detents. No two workers edit the same file concurrently. Product fixes must build, run existing unit tests plus their affected checks and re-shoot before acceptance. Combined tests are still pending; worker-branch results are not a combined pass.

## Devices and capture status

- Integration/reference device: regular Hillclimb iPhone17Pro, iOS26.2 (23C54), local, `78F5A64F-7B2E-4562-8EF9-10F3312CC694`,402x874pt /1206x2622px.
- Only iOS27.1 was initially installed and supports Duo only. Standard26.2 installed and17 created. T3 discovery recovered after the authorized XCTest runner booted it; device_open/device_screenshot now work. Do not reintroduce old tooling-blocker claims.
- Original17 has been returned by D with its app/session closed, light/default restored. Integration validation/capture may now use it. A used private regular17 `066ECE57-46B4-414A-B53E-523775329360`; B has its own listed above. Never use either Duo.
- All interactive launches, settings, input and captures use each task's T3-returned pinned agent-device command. Xcode builds/installs/test runners remain allowed shell work. Do not reuse/close other sessions.
- Activity worker ended only its demo Activities and closed its session. Native expanded Island evidence uses unmodified recording frames because still screenshots omit its overlay; Notification Center banner is not claimed as a truly locked device. Unit-rendered Activity rasters remain explicitly distinct.

## Next verifiable steps

1. A/B/C/D and round2 evidence are merged.249 unit+12 UI=261 passed, zero failures/skips.48 images and production source hashes verified by parent.
2. Run fresh Sol/Astra round2 ratings. Fresh parent arm64 Release confirmation succeeded with new derived data/binary, exit0/BUILD SUCCEEDED; unusual earlier SwiftCompile diagnostics did not recur. Existing AuthManager warnings retained.
3. Fresh Sol and Astra round2 graders. Invoke Opus5.5/medium only if both same-round overall >=8.5.
4. Address next ranked findings in isolated branches; re-shoot/re-grade until final gate or explicit stopping rule. No score improvement is inferred from code/tests.

## Open polish and evidence gaps

- First-line alignment of long-row controls, XXXL capacity placeholder wrapping, and partially clipped empty guide while composing remain for a later task/round.
- Sign-in keyboard-matrix run records an invalid-frame warning; parent result inspection localizes it to testFocusedEmailAndPasswordClearKeyboardInBothAppearances, but no console log is available. XXXL floating Done can overlap lower secondary action in the captured viewport; carry into integrated review.
- Actual locked-device state, arbitrary wallpaper contrast, physical haptics, VoiceOver traversal and broader accessibility-setting interactions remain unverified. Apple Notes references remain unavailable.
- Round1 baseline247 unit tests passed; later repaired fixture stability test1/1 passed. New baseline failures are retained in round1 artifacts; A's new checks now pass on its branch.

Tracking: decisions.md, questions.md, REPORT.md, rounds/<n>/, tasks/<task>/. No current product question requires Edmund. All human shipping actions remain outside authorization.

Written by gpt-6.1-sol in Codex on behalf of Edmund

- D handoff accepted after parent source review, two representative screenshots and16 verified hashes. Read-only List controls disabled while scroll and Done work. All worker scopes are merged; no current worker holds original17. Combined integration validation is next, not yet claimed passed.

- Integration validation/capture task next: new isolated worktree at current merged source, original17 lease, full combined Debug test suite plus Release build, fresh round2 matrix and current native Activity captures. No other worker remains active. Preserve all historical evidence; scripts now support round-specific Activity output.

- Round2 source8dbf6a8, evidence0f0e3dc merged. Parent confirmed48 native image hashes and all recorded production-source hashes. Four previously missing settled Reminders matches now available; Notes remains unavailable. True locked-device capture is optional/unavailable evidence, not a fabricated required programmatic failure. All real unit/UI gates passed. Known sign-in invalid-frame warning recurred.

- Round2 Sol/Astra graders running independently, source remains frozen. Parent fresh Release confirmation resolves compiler-result uncertainty; sign-in invalid-frame runtime warning remains. Before/after original17 screenshot pairs added to REPORT.md.

## Round2 decision and next batch

Both independent reviews complete: Sol8.11(+1.23), Astra8.16(+1.46), minimum7.0 each. Opus is NOT eligible. No plateau yet. Next isolated tasks: E multiline board/capacity/empty-guide and accessible board errors; F sign-in keyboard accessory/warning and accessible notices; G structured Activity overflow accounting through repeated caps. All preserve exact wording/branding/icon. No source edit occurs in integration while workers own files.

## Next worker ownership

- E board-multiline: ReminderListView, ReorderableReminderList, BoardSetupTip, HillclimbGeometry, existing board UI tests and new board tests. Can add loading/error variants through the existing --hillclimb-board-state argument in ReminderListView; DOES NOT own HillclimbDemo.swift.
- F keyboard-recovery: SignInView, HillclimbDemo.swift (only sign-in safe interaction policy), sign-in tests and dedicated helper. No board files. Must disable real auth/provider/external actions in demo while allowing local fields/toggles/scroll/Done.
- G activity-overflow: Activity shared model/layout/controller/widget, dedicated Activity tests/helper, and only necessary pure APNs presentation/backend metadata helpers/tests. No deploy/database migration/live calls. Preserve legacy payload compatibility and do not parse user text as metadata.
- E uses private Board17; F private Auth17; G original17. Every worker closes its own session and reports exact test/capture provenance. Parent re-shoots original17 after merging passing candidates.

## Next-batch handoff: G merged

- G activity-overflow merged (970f567 + parent3020d31). Structured optional hiddenLineCount preserves counts across payload/surface/byte caps; literals resembling +N more are not parsed.266 iOS tests passed (254 unit+12 UI);8 actual native production-pipeline images verified by parent.
- Parent filled assertion dependency cache and ran existing live_activity/board_loader/device_delivery Deno suites. Initial type-check exposed stale empty-board expected shape; added hiddenLineCount:0. Corrected run52 passed,0 failed, no service permissions. Worker’s earlier4 offline tests remain separately recorded.
- Backward compatibility: original lines array retained; missing metadata decodes nil. Already-summarized legacy remote payloads cannot recover lost counts. Backend preparation code is committed ONLY, not deployed; current old remote payload limitation remains until separately authorized work outside this no-deploy hill climb.
- E board-multiline and F keyboard-recovery remain awaiting handoff. They use private regular17 devices; G returned original17 clean, no owned demo Activities, own session closed. No next scores inferred before integrated capture/regrade.

## Next-batch handoff: F merged

- F keyboard-recovery3993113/evidence8c3d9e5 merged after parent source review,20 settled capture hashes and two representative XXXL images. Layout-participating bottom inset reserves Done's real48pt target; alternate action remains separated before/after scrolling, with edge taps and repeated focus/dismissal checks.
- Worker267 combined tests passed (254 units+13 UI), then2 strengthened UI rechecks passed; zero failures/skips. These are worker-base counts, not combined G+F integration counts. UUID-matched backtrace localized prior invalid-frame faults to InputAccessoryBar; subsequent runtime issues and log faults zero. Integrated original17 validation is still required.
- Error announcements deduplicate exact existing text without moving focus. Explicit demo allows local recovery but blocks provider/submit/legal actions, including keyboard submission. Spoken VoiceOver remains unobserved.
- E board-multiline awaits handoff. Original17 remains available for next combined validation after E is accepted.

## Next-batch handoff: E merged; round3 validation next

- E board-multiline9497158/source1add78a accepted after source/test review,48 final-source image hashes and representative XXXL board/error captures. Final265 tests passed (250 units+15 UI), zero failures/skips, four successful builds. Worker-base sign-in warning predates merged F and must be checked again in integration.
- First-line controls preserve44pt geometry and gain semantic contrast. Capacity message is static, intrinsic-height and noneditable with original copy/hint; disabled send/no keyboard focus checked. Flat guide hides while composing and restores unless dismissed. Existing error text announces once per presentation without moving focus. Retry target now44pt and edge-tested.
- E/F/G all merged. No worker holds a device. Next: fresh isolated combined Debug suite, arm64 Release build, original17 full round3 captures including loading/error/keyboard recovery and production Activity counts, then independent Sol/Astra regrade. Expected combined count276 (260 unit+16 UI), to be confirmed by actual runner.

## Round3 evidence retained; required keyboard gate failed

- Evidence08c56a4 merged after parent confirmed102 native image hashes and all production hashes for6959de1. Eight new XXXL Apple references available. Debug/Release succeeded;23 Python and52+4 Deno tests passed. Actual combined result275 passed/1 failed/0 skipped;260 units passed,15/16 UI passed. No round3 score assigned yet.
- Failure: keyboard matrix queried a Keyboard frame after a scroll could interactively dismiss it. Parent test-only correction confines drag to visible form, explicitly checks valid dismissal/refocus, and retains all clearance/target/edge-tap assertions. Required checks remain failed until fresh original17 rerun. No production source changed, prior failed evidence retained.

## Round3 required gates accepted; independent graders running

- Recheck5b0ca7e merged.276/276 passed (260 units+16 UI), zero failures/skips. Three dedicated keyboard repetitions completed24 cases; combined adds8. All original clearance/targets/edge taps remain. Parent verified110 native image hashes and production hash identity to6959de1; test revision542b9f7. Prior failed run remains preserved.
- Fresh Debug build/Python23 passed; Release/backend52+4 explicitly reused based on53 production+11 backend hashes, not rerun claims. Zero observed runtimewarnings andinvalid-frame events; otherdiagnostics retained. Original17 cleaned andreturned.
- Round3 Sol/high andAstra/high are independently grading the identical110-image/source/reference packet. No source edits during reviews. Opus requires both same-roundoverall>=8.5. Quota snapshot exported to rounds/3/usage.json from current-sessionrate-limit metadata.

## Round3 Codex grades complete; Opus eligible

Sol8.78 (minimum7.8), Astra8.76 (minimum7.8), all30 categories. Both exceed8.5, so commission requested Claude Opus5.5/medium on same frozen6959de1 source/110 nativeimages/17 references. Finalall3>=9/everycategory>=7 remains unmet. No plateau: overall scores continue rising. Remaining priorities: light secondary/capacity contrast, composerDonewithnonemptydraft, Account error announcement/recovery, populatedboardretry/diagnostic hierarchy while preserving all wording. No new implementation begins until same-source Opus review is commissioned.
