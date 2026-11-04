# Notepad UI hill climb

Integration: `hillclimb/ui`, based on origin/main `5fc4cbc`. Never merge main, deploy, submit, or force push. Existing untracked files remain untouched.

## Plan and task status

- Done: fetch origin; create and push integration branch.
- In progress: install compatible standard iPhone runtime. Installed iOS 27.1 supports only Duo; 18 Pro and 17 Pro creation both rejected with SimError 403. Downloading iOS 26.2 via Xcode.
- In progress: Xcode downloading 8.39GB iOS 26.2 standard runtime.
- Added: matching Apple Reminders/Notes reference captures (list, bottom, compose, sheet; light/dark) on same regular iPhone 17 Pro.
- Added: measurable regression checks required per fix plus existing tests.
- In progress: isolated sol/high worker implements offline demo fixtures, repeatable captures and executable geometry gates. Source/build validation precedes capture handoff.
- Next: parent captures Apple reference states on standard17; then hand simulator to harness worker.
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
