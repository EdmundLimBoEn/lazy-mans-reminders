# Notepad UI hill climb

Integration: `hillclimb/ui`, based on origin/main `5fc4cbc`. Work is ongoing; score gate not reached. Never merge main, deploy, submit, force push, or touch Edmund's preexisting untracked files.

## Reviewer and stop rules

- Every round: independent gpt-6.1-sol/high and gpt-6-astra/high reviews of the same screenshots, source, checks and Apple reference pairs;30 detailed categories, honest arithmetic-mean overall.
- Edmund's updated rule: Claude Opus5.5/medium ONLY if BOTH Codex graders score >=8.5 overall in the SAME round. This replaces every-other-round scheduling. Round1 is ineligible; Opus has not run.
- Final stop unchanged: ALL THREE graders >=9 overall and NO category below7. Eligibility at8.5 is not completion.
- Also stop for nearly exhausted Codex quota or3 plateau rounds. No quota/limit tool is exposed; no quota estimate is fabricated and no waiting into next weekly window is authorized.

## Scores

| Round | Sol | Astra | Opus | Evidence |
| --- | ---: | ---: | --- | --- |
|0|Not graded|Not graded|Not due|Setup only|
|1|6.88|6.70|Ineligible|18 app captures,5 usable Reminders references; Notes/native Activity initially missing|
|2|Pending|Pending|Only if both Codex >=8.5|Awaiting completed batch, combined checks and original17 re-shoot|

## Current tasks and ownership

| Task | Status | Scope / evidence |
| --- | --- | --- |
|Capture harness|Merged|Offline isolated Debug modes; real geometry probes; repeatable/resumable captures. Round1 retains failed synthesized-scroll attempt and advised successful raw drag.|
|Apple references|Merged, partial|5 usable Reminders references;4 transition frames excluded; Notes unavailable. pairs.json records gaps.|
|A board-reading|Merged|cc98098/ef82a67/9ff1d6c: no final-ink fade, refresh cleanup, compact title/count, actual44pt field/Account/dismiss targets.253 tests passed (247 unit+6 board UI),3 fresh-process pull repetitions,20 capture hashes verified by parent.|
|B signin-surfaces|Awaiting handoff|SignInView/LMRChrome and dedicated new tests; separate regular17 device8E8380DE-364D-4899-99B8-D15ED0494FFD.|
|C activity-polish|Merged|dcc4200/de1ad3a: scalable native Activity rows, independent surface budgets and Island corner clearance.249 unit tests+1 native check each at default/XXXL passed;24 actual native captures verified.|
|D account-surfaces|In progress|Opaque quieter AccountView, safe read-only demo scrolling, new tests. After A handoff, explicitly authorized ONLY Account caller detent state/selection in ReminderListView; no other board edits. Original17 exclusive lease.|

A returned source ownership before D was authorized to edit caller detents. No two workers edit the same file concurrently. Product fixes must build, run existing unit tests plus their affected checks and re-shoot before acceptance. Combined tests are still pending; worker-branch results are not a combined pass.

## Devices and capture status

- Integration/reference device: regular Hillclimb iPhone17Pro, iOS26.2 (23C54), local, `78F5A64F-7B2E-4562-8EF9-10F3312CC694`,402x874pt /1206x2622px.
- Only iOS27.1 was initially installed and supports Duo only. Standard26.2 installed and17 created. T3 discovery recovered after the authorized XCTest runner booted it; device_open/device_screenshot now work. Do not reintroduce old tooling-blocker claims.
- Original17 is currently handed to D. Parent waits for clean handback before integration testing/captures. A used private regular17 `066ECE57-46B4-414A-B53E-523775329360`; B has its own listed above. Never use either Duo.
- All interactive launches, settings, input and captures use each task's T3-returned pinned agent-device command. Xcode builds/installs/test runners remain allowed shell work. Do not reuse/close other sessions.
- Activity worker ended only its demo Activities and closed its session. Native expanded Island evidence uses unmodified recording frames because still screenshots omit its overlay; Notification Center banner is not claimed as a truly locked device. Unit-rendered Activity rasters remain explicitly distinct.

## Next verifiable steps

1. Review/merge B and D passing results, preserving copy/branding/icon and offline isolation.
2. Build and run combined existing/affected tests; Release build; capture all matching states on original17, including native Activity evidence on integrated source.
3. Fresh Sol and Astra round2 graders. Invoke Opus5.5/medium only if both same-round overall >=8.5.
4. Address next ranked findings in isolated branches; re-shoot/re-grade until final gate or explicit stopping rule. No score improvement is inferred from code/tests.

## Open polish and evidence gaps

- First-line alignment of long-row controls, XXXL capacity placeholder wrapping, and partially clipped empty guide while composing remain for a later task/round.
- Actual locked-device state, arbitrary wallpaper contrast, physical haptics, VoiceOver traversal and broader accessibility-setting interactions remain unverified. Apple Notes references remain unavailable.
- Round1 baseline247 unit tests passed; later repaired fixture stability test1/1 passed. New baseline failures are retained in round1 artifacts; A's new checks now pass on its branch.

Tracking: decisions.md, questions.md, REPORT.md, rounds/<n>/, tasks/<task>/. No current product question requires Edmund. All human shipping actions remain outside authorization.

Written by gpt-6.1-sol in Codex on behalf of Edmund
