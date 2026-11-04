# Hill climb state

Integration branch: `hillclimb/ui`. Main, deployment, App Store/TestFlight and force pushes are prohibited. Original user untracked files remain untouched. Latest graded app/test source: `b5d9bb3`. The integration branch now includes K; the next combined validation will freeze a new source revision.

## Current plan

1. Round 4 Sol/high and Astra/high reviews complete: **8.97 and 8.95**. Opus review complete: **8.51**, minimum **7.6**. Continue the next fix batch.
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
| 4 | gpt-6.1-sol | 8.97 | 8.1 |
| 4 | gpt-6-astra | 8.95 | 8.2 |
| 4 | Claude Opus 5.5 | 8.51 | 7.6 |

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
| Round 4 independent Codex grading | Complete | `rounds/4/scores-gpt-*.md/json` |

## Current runtime evidence

Round 4: **285/285 passed**, comprising 263 unit and 22 UI tests; zero failures/skips. Fresh unsigned arm64 Debug and Release builds, 23 iOS Python checks and 52+4 offline Deno tests passed. All eight normal-settings post-scroll keyboard cases and edge taps completed. Runtime warnings and scoped invalid-frame events were zero; 9,359 other error/fault events remain recorded.

Parent verified all **288 native PNG hashes** and production input hashes. There are seven recordings and 17 usable Apple Reminders reference images. Twelve unit-rendered Activity rasters are separate and never count as simulator captures. Reference mismatches and rejected transitions remain explicit.

Actual Settings UI enabled Reduce Motion, Reduce Transparency and Increase Contrast, captured selected states, then restored all three to Off. One combined-settings still omits the alternate sign-in action; the recording shows it elsewhere. A complete repeatable clearance matrix is unproven, and unreachability is not diagnosed. Top-edge board fragments remain observed; bottom-row geometry and ink pass.

New independent reviewer measurements identify low-contrast normal-size error text in SignIn/Account. Existing helper/footer raster checks excluded semantic error red. This remains a new finding to address after the frozen round 4 reviews; no passing error-contrast gate is claimed.

## Devices and ownership

L and K released their private devices. The restoration recheck changed no settings. Its owner closed its own original17 session without shutdown (cleanup d3e70bd). A new combined validation uses a fresh owned session and the standard test runner; never reuse or close the previous owner session.

- Original17: `local`, `78F5A64F-7B2E-4562-8EF9-10F3312CC694`.
- Private Board17: `066ECE57-46B4-414A-B53E-523775329360`.
- Private Auth17: `8E8380DE-364D-4899-99B8-D15ED0494FFD`.

All are regular iPhone 17 Pro/iOS 26.2; no Duo was used. New device work requires a new owned `device_open` session and its returned pinned command. Never reuse another worker session.

## Constraints and open questions

Preserve every user-facing string, branding and icon. No nested cards or decorative red/orange palette. Edmund confirmed on 2026-11-05: “Keep existing wording.” The raw network-error copy remains verbatim; the optional question in `questions.md` is closed.

True physical Lock Screen, haptics, spoken VoiceOver, AX1–AX5, live account/auth flows and launch/frame-time metrics remain unverified. Selected system-setting captures do not certify every combination. Notification Center is not true device locking, and encoded recording frame rates are not display-performance metrics.

Quota: current-session metadata reports **14% used** in the 10,080-minute weekly window; exact timestamp and fields are in `rounds/4/usage.json`. Check after each round; never wait into or spend against the next window.

`REPORT.md` tracks category scores, before/after pairs, merged work and phone installation. The separate numerical validator retains the final all-three score rule; reviewer status is informational, not a circular programmatic requirement.

Written by gpt-6.1-sol in Codex on behalf of Edmund

## Round 4 grade decision

Validator confirms both Codex reports and required checks; only Opus is missing. Both overall scores exceed 8.5, so run the exact requested Opus 5.5/medium reviewer now. Final gate is still false. Scores continue increasing; three-round plateau is not established. Top remaining findings: board header-edge fragments, normal-size error/diagnostic text contrast, and targeted accessibility/Activity verification. Existing copy remains fixed; Edmund confirmed retaining it on 2026-11-05.

## Round 4 Opus and next batch

Opus a9ea0dd is merged; all three reports validate with no schema/evidence errors, but the final numeric gate remains false. No three-round plateau: all completed grader series continue increasing. Next isolated workers: K sign-in/Account error contrast, legal-footer capture coverage and combined-settings keyboard reproduction; L board top edge, single VoiceOver paragraph stop and loading/error text contrast; M Activity readability/density investigation with actual native safety gates. Retain existing wording, as Edmund confirmed on 2026-11-05. Each branch must build, pass existing+new checks and capture affected native states before acceptance.

## Next worker ownership (K/L/M)

- K: SignInView.swift, AccountView.swift, SignInSurfaceUITests.swift, new error-contrast/settings UI tests and task-local evidence. Private Auth17. Reproduce actual combined system settings, preserve normal keyboard tests, fix error/diagnostic contrast and safe enabled legal-link appearance.
- L: ReminderListView.swift, ReorderableReminderList.swift, HillclimbGeometry.swift, existing board UI tests and new board tests. Private Board17. Native top-edge treatment, one accessible paragraph stop, and readable board loading/error text. No sign-in or Account edits.
- M: Shared Activity layout/model presentation and widget, dedicated Activity tests/new performance-only UI file. Original17. Investigate native density/word-boundary readability while retaining adaptive type, count conservation and footer/corner gates; optionally collect public simulator launch metrics. No global demo/harness or other workers' test files.

All use isolated tool-created worktrees off the current integration branch, build and pass the full existing285-test baseline plus new checks, capture actual affected states and hand back their own device sessions. Production copy remains fixed.

## M handoff: experiment retained; renderer unchanged

- Candidate6a563b1 was reviewed:289candidate tests passed (267unit+22UI),12nativePNGhashesverified,eightvisiblecount/ink/cornergatespassed,fourrecordingsretained. No launch metric was recorded.
- Parent declined the rendering change: word-boundary truncation removes the last word from a previously complete XXXL first row while keeping2+8. This is not an adequate readability/density improvement. Native renderer/type/margins/counts remain unchanged. Candidate source/tests saved as tasks/activity-readability/candidate.patch, with exact worker evidence and an explicit PM disposition. Candidate tests are not integrated acceptance.
- Original17 is returned light/Large, ownedActivitiesempty,ownsessionclosed,running. K/privateAuth17 andL/privateBoard17 remain active. Round5 combined validation follows their handoffs.

## K handoff accepted; test-only cleanup follow-up pending

- K2e6aa8c/evidence41c2027 merged after source/safety review,110nativeattachment+13acceptedmanualPNGhashes verified. Primary diagnostic/destructive-title ink retains exact copy, glyphs and roles. Enabled-style legal links now have primary tint, retain root inertness and explicitly discard all demo external URLs; normal production URLs use system handling.
- Worker291/291 (263unit+28UI),zero failures/skips.44nativecontrastgates passed, minimum12.06:1. All8normal+8actualcombined-system-settingskeyboardcasespassed;Done48pt,alternateclearance>=116pt. No keyboard production change was justified or made. Runtimewarnings/invalidframeevents0;15,220otherlogeventsandcompilerdiagnosticsretained.
- PrivateAuth17 settings were restored manually, including incidental Auto-Play Message Effects drift. Parent adds a small TEST-ONLY teardown correction to remember/restore that dependent setting automatically. This correction is not yet runtime-verified; next combined original17 validation must execute it and confirm restoration. Do not attribute the worker291pass to the newer test revision.
- K ownsessionclosed,light/Large,Activitiesempty,devicebooted. L board-edge worker remains active. M renderer is unchanged after rejected experiment. Integrated round5 validation follows L handoff and includes this teardown check.

## Focused cleanup recheck assigned

A new isolated test worker uses original17 to rebuild the integration source and execute the two AccessibilitySettingsUITests with the parent teardown correction. It must verify the original and restored Auto-Play Message Effects value plus all three requested switches, preserve real keyboard/raster assertions, and report actual counts. No production edits. This runs alongside L's separate privateBoard17 work; full round5 validation waits for both leases to return.

## L accepted; focused restoration attempt retained without a pass

- L0265cb4/evidence46e6b4f merged after source/native review and144 verified final native PNG hashes (60manual+84XCTest). Worker287/287 (263unit+24UI), zero failures/skips, retains all285 baseline IDs. Top-only24pt mask affects departed content; fresh top/pull has none. Accessibility settings use6pt opaque boundary. Bottom fade remains off; final-row geometry/ink still pass. Duplicate paragraph reading node removed; loading/error text contrast21:1. Speech is unobserved.
- Teardown recheck1eb1f9c built successfully but ran0tests. Snapshot-reference failure and its single advised retry failed; no pass inferred. OriginalReduceMotionOff/AutoPlayMessageEffectsOn were read, no settings changed. Its test-only value instrumentation and exact failures are merged for the combined run.
- Combined K+L expected293tests (263unit+30UI); actual runner counts authoritative. All app fixes now integrated, Activity renderer unchanged. Next isolated round5 validation runs focusedSettingspreflight, fullsuite, freshDebug/Release/otherchecks and fullmatrix on original17. Restoration is pending until executed proofs match all4original values.

## Round5 validation assigned

All K/L source changes and restoration instrumentation are merged. The previous owner closed only its own original17 session successfully; no active worker owns a device. New combined validation uses a fresh original17 session and the authorized XCTest runner, starting with both Settings methods to verify all4original/restored values. Full expected293tests includes K+L; actual counts are authoritative. Fresh Debug/Release/other checks and all native states precede fresh independent grades. Optional public launch metrics may add one test; no unmeasured timing claim is allowed.
