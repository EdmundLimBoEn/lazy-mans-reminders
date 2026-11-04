# Hill climb state

Integration branch: `hillclimb/ui`. Main, deployment, App Store/TestFlight and force pushes are prohibited. Original user untracked files remain untouched. Current frozen app/test source: `b5d9bb3`.

## Current plan

1. Complete independent round 4 Sol/high and Astra/high reviews of the same frozen packet. **Running.**
2. Validate both reports. Run Opus 5.5/medium only if both same-round Codex overall scores are at least 8.5.
3. Turn remaining findings into isolated, non-overlapping worker tasks. Each worker builds, passes the existing tests plus measurable regression gates, and captures affected screens before handoff.
4. Merge passing branches into `hillclimb/ui`, run combined original17 validation, re-shoot the full matrix and re-grade.
5. Stop only when all three graders score at least 9 with no category below 7, near actual quota exhaustion, or after three plateau rounds. No success or plateau is currently established.

## Scores

| Round | Grader | Overall | Lowest category |
| --- | --- | ---: | ---: |
| 1 | gpt-6.1-sol | 6.88 | 4 |
| 1 | gpt-6-astra | 6.70 | 4 |
| 2 | gpt-6.1-sol | 8.11 | 7 |
| 2 | gpt-6-astra | 8.16 | 7 |
| 3 | gpt-6.1-sol | 8.78 | 7.8 |
| 3 | gpt-6-astra | 8.76 | 7.8 |
| 3 | claude-opus-5.5 | 8.25 | 7.5 |
| 4 | gpt-6.1-sol | Pending | Pending |
| 4 | gpt-6-astra | Pending | Pending |
| 4 | Claude Opus 5.5 | Eligibility pending | — |

Each report has all 30 rubric categories. Round 1 and 2 were not Opus eligible. Round 3 passed the 8.5 eligibility threshold but did not meet the final stop gate. Reports and machine-readable scores live under `rounds/<n>/`.

## Task status

| Task | Status | Evidence |
| --- | --- | --- |
| Offline demo harness, geometry gates, repeatable capture scripts | Merged | `harness.md`, `scripts/hillclimb/` |
| Apple reference captures | Merged; Notes unavailable | `reference/manifest.json`, `reference/round2/`, `reference/round3/` |
| Board final-line ink, refresh settling, 44pt controls | Merged | `tasks/board-reading/` |
| Native Activity corner clearance and scalable layout | Merged | `tasks/activity-polish/` |
| Flat sign-in surfaces | Merged | `tasks/signin-surfaces/` |
| Opaque Account sheet and detents | Merged | `tasks/account-surfaces/` |
| Structured Activity overflow counts | Merged; backend preparation not deployed | `tasks/activity-overflow/` |
| Sign-in keyboard recovery and announcements | Merged | `tasks/keyboard-recovery/` |
| Multiline board, capacity wrapping and errors | Merged | `tasks/board-multiline/` |
| Interactive-dismissal test correction | Merged; round 3 recheck passed | `validation/round3/recheck/` |
| H: deliberate board completion, persistent Done, readable status/retry | Merged `aa69cb4` | `tasks/board-deliberate/` |
| I: native Apple button, sign-in contrast and compact inset | Merged `551f880` | `tasks/signin-native/` |
| J: Account typography, alignment and exact error announcements | Merged `7abefed` | `tasks/account-consistency/` |
| Round 4 combined validation and native captures | Merged `5c43ea3` | `validation/round4/`, `rounds/4/` |
| Round 4 independent Codex grading | Running | Reports pending |

## Current runtime evidence

Round 4: **285/285 passed**, comprising 263 unit and 22 UI tests; zero failures/skips. Fresh unsigned arm64 Debug and Release builds, 23 iOS Python checks and 52+4 offline Deno tests passed. All eight normal-settings post-scroll keyboard cases and edge taps completed. Runtime warnings and scoped invalid-frame events were zero; 9,359 other error/fault events remain recorded.

Parent verified all **288 native PNG hashes** and production input hashes. There are seven recordings and 17 usable Apple Reminders reference images. Twelve unit-rendered Activity rasters are separate and never count as simulator captures. Reference mismatches and rejected transitions remain explicit.

Actual Settings UI enabled Reduce Motion, Reduce Transparency and Increase Contrast, captured selected states, then restored all three to Off. One combined-settings still omits the alternate sign-in action; the recording shows it elsewhere. A complete repeatable clearance matrix is unproven, and unreachability is not diagnosed. Top-edge board fragments remain observed; bottom-row geometry and ink pass.

New independent reviewer measurements identify low-contrast normal-size error text in SignIn/Account. Existing helper/footer raster checks excluded semantic error red. This remains a new finding to address after the frozen round 4 reviews; no passing error-contrast gate is claimed.

## Devices and ownership

All worker sessions are closed. No current device lease is active. Original17 remains booted, light/Large, accessibility switches Off and owned demo Activity IDs empty.

- Original17: `local`, `78F5A64F-7B2E-4562-8EF9-10F3312CC694`.
- Private Board17: `066ECE57-46B4-414A-B53E-523775329360`.
- Private Auth17: `8E8380DE-364D-4899-99B8-D15ED0494FFD`.

All are regular iPhone 17 Pro/iOS 26.2; no Duo was used. New device work requires a new owned `device_open` session and its returned pinned command. Never reuse another worker session.

## Constraints and open questions

Preserve every user-facing string, branding and icon. No nested cards or decorative red/orange palette. The optional raw network-error wording question remains pending in `questions.md`; current copy stays intact and independent work continues.

True physical Lock Screen, haptics, spoken VoiceOver, AX1–AX5, live account/auth flows and launch/frame-time metrics remain unverified. Selected system-setting captures do not certify every combination. Notification Center is not true device locking, and encoded recording frame rates are not display-performance metrics.

Quota: current-session metadata reports **12% used** in the 10,080-minute weekly window; exact timestamp and fields are in `rounds/4/usage.json`. Check after each round; never wait into or spend against the next window.

`REPORT.md` tracks category scores, before/after pairs, merged work and phone installation. The separate numerical validator retains the final all-three score rule; reviewer status is informational, not a circular programmatic requirement.

Written by gpt-6.1-sol in Codex on behalf of Edmund
