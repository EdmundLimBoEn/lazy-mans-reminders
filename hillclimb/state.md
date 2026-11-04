# Notepad UI hill climb

Integration: `hillclimb/ui`, based on origin/main `5fc4cbc`. Never merge main, deploy, submit, or force push. Existing untracked files remain untouched.

## Plan and task status

- Done: fetch origin; create and push integration branch.
- Done: installed iOS 26.2 (23C54); created regular Hillclimb iPhone 17 Pro, UUID `78F5A64F-7B2E-4562-8EF9-10F3312CC694`.
- Resolved: T3 discovery now lists the regular17 after the authorized XCTest runner booted it. Runtime XCTest and geometry baseline are running; captures follow completion.
- Added: matching Apple Reminders/Notes reference captures (list, bottom, compose, sheet; light/dark) on same regular iPhone 17 Pro.
- Added: measurable regression checks required per fix plus existing tests.
- Prepared, NOT merged: capture-harness branch commit `f0e4f513f9df290f96a0f7c6fdb0d5d533888241`. Worker reports Debug build-for-testing, Release build and 23 Python iOS checks passed. Existing XCTest suite, UI geometry execution and all captures remain unrun. Await device-tool access before integration.
- Next: parent captures Apple reference states on standard17; then hand simulator to harness worker.
- Done: score aggregation rejects missing evidence, arithmetic mismatch and unmet stop gate; synthetic validation exercised accepted and rejected cases.
- Pending: independent sol/high and astra/high baseline graders, highest-impact isolated fix workers, merge only verified work.
- Pending: re-capture/re-grade Codex-only rounds; run Claude Opus 5.5 at medium effort ONLY for a round where BOTH gpt-6.1-sol and gpt-6-astra score >=8.5 overall in that same round. No every-other-round schedule. Check usage after each round.
- Pending: final category comparison, screenshot pairs, install instructions.

## Scores

| Round | sol | astra | Opus | Evidence |
| --- | --- | --- | --- | --- |
| 0 | not graded | not graded | not due | Setup only |
| 1 | 6.88 | 6.70 | not eligible (<8.5) | 18 app shots, 5 usable Reminders references; Notes/Activity gaps |

## Constraints and stop rules

Stop only at requested score gate, nearly exhausted Codex quota, three plateau rounds, or a concrete tool/platform blocker. No scores for unseen screens. No Duo substitution. Use T3 device tools for all device interactions/captures. Build/install/test via Xcode allowed.

Written by gpt-6.1-sol in Codex on behalf of Edmund

## Resume checklist

1. Refresh/restart T3 device discovery until the regular17 UUID is listed and device_open succeeds. Do not use Duo or a CLI bypass.
2. Capture Apple Reminders/Notes matching states; then hand device to a fresh validation task on prepared harness commit.
3. Run existing XCTest and new UI tests, retain baseline failures, capture actual app states. Merge preparatory harness only once validated.
4. Run both independent Codex graders with source + Apple pairs. No rating round has completed yet; no plateau/score stop criterion reached.

Task resumed; runtime validation in progress. No UI fix has been merged; no PR, main merge or deployment.

## Runtime baseline follow-up

- Existing iOS suite: 247 passed on regular17/iOS26.2. UI composer target failed at 22pt height versus 44pt minimum.
- Interrupted long scrolling UI test after >10 minutes of blind repeated edge swipes; not a passed or completed geometry gate. Raw summary in validation/baseline-test-summary.json.
- Prepared harness follow-up bounds traversal, detects no progress, and identifies the actual final fixture row using fixture count instead of the last observed row. Assertions remain intact; revalidation pending.
- T3 device_open and device_screenshot now work. Parent opened Reminders, completed welcome, left iCloud opt-in unanswered, closed own app session. Reference worker receives exclusive device handoff next. No auth/sign-in or sync enabled.

## Round 1 grading handoff

18 actual app PNGs verified and committed. Five usable Apple Reminders references; Notes unavailable, four transition references excluded. pairs.json records exact matches and gaps. Two independent 30-category Codex graders next. No production UI fixes merged yet. Baseline checks: existing247pass; XXXL pass; field22pt and Account36pt fail; pull idle timeout; fixture query fix pending rerun. Codex quota tool is not exposed; no quota claim made.

- Runtime follow-up: repaired offline fixture stability test actually executed (1 test) and passed. Source/test packet otherwise frozen during independent round1 grading.

## Current batch: round 2 candidates

- A: final-line readability + pull-to-refresh settling. Own ReminderListView.swift, ReorderableReminderList.swift, HillclimbGeometry.swift and existing UI tests. Priority highest. Includes actual rendered ink/fade boundary gate; do not weaken existing assertions. Touch-target work in same files follows serially if scope permits a separately reviewable commit.
- B: sign-in surface simplification. Own SignInView.swift and dedicated new tests only; preserve every user-facing string and provider flow.
- C: native Live Activity/Island layout and isolated actual Activity evidence. Own Widget/ReminderLiveActivity.swift, Shared/LockScreenLineBudget.swift/related dedicated tests, HillclimbDemo.swift and a new Debug helper; do not touch A files.
- Device lease: original regular17 stays parent-controlled for integration re-shooting. Parallel workers use tool-discovered separate regular17 simulators or request an explicit handoff; no concurrent test/UI action on same device. Avoid Duo.
- Each worker must build, execute existing tests plus affected gates and save affected screenshots before done. Product fixes merge only after passing relevant gates.

Quota check after round1: no limit/usage tool exposed in current catalog. Do not infer remaining weekly quota; stop on actual near-limit indication if available. No weekly-window waiting authorized.

## Current reviewer eligibility and final stop rule

Edmund's updated rule supersedes the original every-other-round Opus schedule: only invoke Claude Opus 5.5 / medium after BOTH Codex graders score >=8.5 overall for the SAME round. Otherwise continue Codex-only rounds. Round 1 is not eligible.

The final stop rule is unchanged: gpt-6.1-sol, gpt-6-astra and Claude Opus 5.5 must ALL score >=9 overall, with NO category below 7. The 8.5 eligibility threshold does not satisfy the final stop rule.

## Batch handoff update: Activity merged

- C COMPLETE and merged: dcc4200 + de1ad3a. Scalable native Activity text, per-surface row budgets, rounded-Island corner clearance, explicit offline demo and real native evidence. Parent reviewed source, two representative native captures, test summaries, and all24 capture hashes. 249 unit tests passed; native Island check1/1 at default and1/1 at XXXL. True locked-device state unavailable; Notification Center banner and recorded expanded Island are actual native evidence. Do not call intermediate candidate image a round1 baseline.
- A board-reading: awaiting handoff, assigned066ECE57-46B4-414A-B53E-523775329360; owns board/list/probe/existing UI-test files.
- B signin-surfaces: awaiting handoff, assigned8E8380DE-364D-4899-99B8-D15ED0494FFD; owns SignInView/LMRChrome/new sign-in tests.
- D account surfaces: next isolated task, AccountView.swift plus new account tests only. Can use original17 after C's clean handback. No overlapping edits with A.
- Next integration round remains pending A/B/D results, combined build/checks, all-state re-shoot on original17, two fresh Codex grades. Opus only if both same-round Codex overall >=8.5. Final stop remains all3 >=9 and every category >=7.

## Batch handoff update: Board merged

- A COMPLETE and merged: cc98098/ef82a67/9ff1d6c. Removed composer overhang and both bottom edge fades, single populated-list refresh owner with cleanup, compact title/count remains visible, actual44pt Account/input/dismiss targets. Parent reviewed source, relevant screenshot samples, test summaries and all20 capture hashes.
- A validation:253 tests passed (247 unit +6 board UI), zero failures/skips. Pull check additionally3 fresh-process repetitions; full pull/idle and actual final-line pixel-contrast assertions remain enabled. Tests were on A branch before C integration; combined suite still pending.
- Optional first-line row-control alignment, XXXL capacity placeholder and clipped empty-guide fragments remain for a later task/round; no scores inferred.
- B sign-in and D account await handoff. A-owned board files are now free; D may adjust only Account caller detent selection after explicit PM handoff.
