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
- Pending: re-capture/re-grade rounds, Opus 5.5 medium every other round or at Codex gate, usage check after each round.
- Pending: final category comparison, screenshot pairs, install instructions.

## Scores

| Round | sol | astra | Opus | Evidence |
| --- | --- | --- | --- | --- |
| 0 | pending | pending | not due | No screenshots yet |

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
