# Hill climb state

Integration branch: `hillclimb/ui`. All accepted work is merged and pushed here. Never merge to main, force push, deploy, or upload to App Store/TestFlight. Original user untracked files remain untouched.

## Current plan

1. Round 6 reviews are complete: Sol **8.83/minimum 7.8**, Astra **8.92/minimum 8.0**. Both identify Account/sign-in/capacity-footer density. Fix that feedback in the next isolated batch.
2. Validate both independent 30-category reports. Only run Opus 5.5/medium if both same-round Codex overall scores are at least 8.5. Use Cursor Opus 5.5/medium if Claude API tokens run out; that exact provider/model/effort is confirmed available.
3. Turn actionable findings, including the crowding concern, into small isolated tasks with non-overlapping source ownership. Each task builds, passes the existing suite and meaningful new checks, then captures affected native states before acceptance.
4. Revalidate and re-shoot the integrated source before the next grading round. Preserve every user-facing word, branding and icon. No nested cards or decorative red/orange palette.
5. Stop only when all three graders are at least 9 with no category below 7, actual Codex quota is nearly exhausted, or scores plateau for three rounds. No final success or plateau is established. Latest usage snapshot: 23% of the current weekly window used.

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
| 5 | gpt-6.1-sol | 9.06 | 8.0 |
| 5 | gpt-6-astra | 9.15 | 8.2 |
| 5 | Claude Opus 5.5 | 8.69 | 7.8 |
| 6 | gpt-6.1-sol | 8.83 | 7.8 |
| 6 | gpt-6-astra | 8.92 | 8.0 |

Each report uses the exact 30 rubric categories and arithmetic mean rounded to two decimals. Rounds 1–2 were not Opus eligible. Round 6 Codex reports validate. Opus is eligible but deferred until after the crowding batch to conserve limited Claude tokens. Round 5 remains the latest three-grader round. Reports and machine-readable aggregates are under `rounds/<n>/`.

## Round 6 accepted verification

Graded app/test revision: **b846a9155dd4b1dd773482f6cc4169a73441ba25**. Accepted recheck evidence: `67fb800`. Historical screenshot acquisition revision: `6333a32734fffab457e100777f3515de831effae`. All 54 production files are byte-identical across these revisions and assigned `d0a1985`; new test revision and binary identities are separately recorded.

- **308/308 passed:** 263 unit + 45 UI; zero failures/skips and all 307/304/293 prior named IDs retained.
- All three Settings-changing methods independently restore Reduce Motion, Auto-Play Message Effects, Reduce Transparency and Increase Contrast to their original values at each teardown.
- Fresh Debug build/full suite passed. Earlier fresh Release, Python 23 and Deno 52+4 results are explicitly reused only with matching production/backend/package hashes.
- 537 historical qualifying PNGs plus 20 new native supplements; counts include repeated samples. Nine short recordings and 17 usable Apple Reminders references. Parent verified every historical image/reference hash, all 20 new image hashes/dimensions, and integrated production hashes. Notes is unavailable; semantic/configuration reference gaps remain explicit.
- Actual ordinary-fixture gestures pass all four style/size variants. XXXL content moves 127pt and the footer clears the safe bottom by 50.33pt. Separate enabled-appearance tests preserve geometry, visible ink and inertness.
- The original appearance-fixture gesture failure remains recorded as `contract_invalid`, required:false. Its root deliberately disables hit testing. No production defect or fix is invented; the corrected actual-gesture check is required and passed.
- Test timeout/interruption and a 1389.957s keyboard-method runner-duration outlier remain disclosed. A passing test is not responsiveness proof. Runtime invalid-frame events are zero; other diagnostic events remain retained.
- Public five-sample simulator Debug launch, scroll elapsed and scrolling-signpost duration metrics establish a baseline. They do not establish frame pacing, hardware feel or a before/after improvement. See both original and recheck metric samples and host-load observations.

Evidence: `validation/round6/README.md`, `validation/round6/recheck/README.md`, `rounds/6/checks.json`, `rounds/6/inventory.json`, `rounds/6/usage.json`. Unit-rendered rasters remain separate from native captures. Protected XCTest secure-keyboard images are partial; full-device supplements provide complete keyboard views.

## Accepted tasks

| Task | Status | Evidence |
| --- | --- | --- |
| Offline fixtures, screenshot harness and geometry gates | Merged | `harness.md`, `scripts/hillclimb/` |
| Apple references | 17 usable Reminders images; Notes unavailable | `reference/` |
| Final-row ink, pull-down settling and 44pt board controls | Merged | `tasks/board-reading/` |
| Activity scalable layout, lower-corner clearance and hidden counts | Merged; backend preparation undeployed | `tasks/activity-polish/`, `tasks/activity-overflow/` |
| Flat sign-in and opaque Account presentation | Merged | `tasks/signin-surfaces/`, `tasks/account-surfaces/` |
| Keyboard recovery and exact-text announcements | Merged | `tasks/keyboard-recovery/` |
| Multiline board, capacity wrapping and errors | Merged | `tasks/board-multiline/` |
| H/I/J deliberate completion, native sign-in, Account consistency | Merged | `tasks/board-deliberate/`, `tasks/signin-native/`, `tasks/account-consistency/` |
| K error contrast, legal fixture and combined-settings proof | Merged | `tasks/error-keyboard/` |
| L board top edge, readable diagnostics and single AX stop | Merged | `tasks/board-edge-accessibility/` |
| M manual word-boundary renderer | Rejected: lost content; evidence retained | `tasks/activity-readability/` |
| N full-board Add removal | Merged; four native transition checks | `tasks/board-capacity/` |
| O persistent Password label and native top edge | Merged; footer reachability and loading-label samples | `tasks/signin-chrome/` |
| P native Island-only tightening | Merged; complete short XXXL sample lines, counts unchanged | `tasks/activity-tightening/` |
| Q Account hard edge, paragraph spacing and Done size | Merged; exact wording, 6pt spacing, 44pt on-screen target | `tasks/account-chrome/` |
| Combined round 6 and corrected gesture proof | Merged; all required gates pass | `validation/round6/`, `validation/round6/recheck/` |
| Round 6 independent Codex reviews | Complete; density findings accepted | `rounds/6/` |

## Edmund’s crowding priority

Direct feedback: “looks croweded as fuck”; check it on the next pass. Account and sign-in were the recently displayed states. Assess breathing room, dense text blocks, section rhythm, repetitive chrome and competing controls at default and XXXL, against Apple references. Distinguish synthetic long stress content from actual layout problems. High screenshot scores and passing geometry checks do not supersede this concern. Preserve wording and Dynamic Type; do not manufacture calm by shrinking text or removing information. Reviewers must propose concrete source-owned changes and measurable checks where supported.

## Devices and ownership

All workers have released their sessions. Account density worker R owns original17 in a new isolated session; upcoming S sign-in and T capacity-footer workers use separate private devices. Review agents are complete. Original17 is running light/Large, original switches restored, no owned Activities, and own app/Settings/session/panel closed.

| Device | Host | ID |
| --- | --- | --- |
| Original17 | local | `78F5A64F-7B2E-4562-8EF9-10F3312CC694` |
| Private Board17 | local | `066ECE57-46B4-414A-B53E-523775329360` |
| Private Auth17 | local | `8E8380DE-364D-4899-99B8-D15ED0494FFD` |

All are regular iPhone 17 Pro/iOS 26.2; no Duo. New device work requires a new owned `device_open` session and its pinned command. Never reuse or close another worker’s session.

## Constraints and remaining limits

Edmund confirmed “Keep existing wording.” The raw network-error copy is intentional and the optional question is closed. No product question is pending. Claude usage remains moderate and eligibility-gated; Cursor fallback is authorized only when API tokens run out.

Physical haptics, spoken VoiceOver, true locked-device behavior/wallpapers, AX1–AX5, live authentication/AutoFill and hardware frame performance remain unobserved. Very long Activity lines still truncate natively; compact/minimal content remains intentionally empty. The board’s 24pt top mask and 6pt opaque accessibility boundary are custom treatments, not a claim of Apple’s native blur.

Detailed historical actions and rejected attempts remain in `decisions.md`, task evidence and Git history. A root Git read stall was repaired by restoring only committed sign-in evidence to byte-identical HEAD content; no application or user files changed.

Written by gpt-6.1-sol in Codex on behalf of Edmund

## Density pass starts in parallel with frozen round 6 reviews

Account is the clearest source-supported crowding task: AccountView explicitly uses compact section spacing and the full guidance is primary ink. One isolated worker will compare native default grouped spacing and quieter accessible explanatory ink, preserving every word and all controls. It owns only AccountView, BoardPersistenceSection, a new AccountDensity UI test and task evidence on original17. Round6 reviewers continue against unchanged root/frozen production; no worker code is merged during their review. Candidate acceptance requires native before/after improvement, >=7:1 guidance contrast, full reachability and all308baseline tests plus new checks.

## Density batch ownership and reviewer routing

Both round 6 reports validate all30categories,557screenshot paths,17refs and exact means. The lower ratings explicitly reflect crowding/hierarchy findings, not failed safety gates. No three-round plateau is established.

- R Account is active: native section rhythm, passive identity chrome, quieter explanatory ink with >=7:1 guidance contrast and distinct semantic boundaries.
- S Sign-in is next: unpainted field/helper/action groups with 6–8pt internal and 16–20pt between-field spacing, preserving all methods, words and targets.
- T capacity footer is next: status first, unchanged hint second, shared leading edge and no taller footer; preserve final-row clearance and normal composer behavior. Prefer this bounded reviewer-supported layout over moving content into a new list footer.

Opus eligibility is true, but defer this round’s optional Opus run until the revised density batch; Claude API tokens are limited and the direct user concern is already actionable. This does not change the numeric eligibility or final stop rules, and no missing Opus score is invented. R7 must use fresh combined validation/captures and independent Codex reports before another Opus call. Exact Cursor Opus5.5/medium remains the authorized quota fallback.

## Density-batch validation scheduling

R reported an unchanged BoardEdge gesture timeout during shared-host load above200. Parent observed concurrent R/S/T full-suite xcodebuild processes; this is a plausible environmental confound, not a proven product diagnosis. All workers must finish current runs safely, restore each Settings teardown, retain failures and avoid new full-suite/rebuild attempts. Source/evidence analysis may continue. Any failed candidate hands back explicitly pending validation; parent will commission one serialized quiet recheck after current suites finish. No merge or passing claim without a real full-suite pass. No test weakening or retry-until-pass.

## Latest user priority: login composition

Edmund clarified that the “home screen” he finds ugly means **the login screen**, not the board. Prioritize default Sign In’s overall composition as well as XXXL density. Parent observed the large Sign In navigation title competing with the Notepad/intro group and similar filled provider/input/submit surfaces with inconsistent emphasis. These are visual hierarchy hypotheses, not an authentication defect. A spacing-only candidate must not be declared sufficient from passing tests; inspect matched default light/dark enabled-style before/after shots. Consider native title scale/placement and coherent control treatments in a subsequent bounded refinement if needed, preserving every word, branding, provider order and native Apple rendering. No current frozen test binary is changed midrun; serialized validation scheduling remains active.

## R and T handbacks retained; candidates not accepted

R Account candidate `6eaf884`/evidence `8fa1c22`: native gaps12→35pt, guidance-to-Sign Out12→23.67pt, helper contrast>=8.51:1 and guidance9.72:1, exact copy/6pt paragraphs retained. 308/310 passed; BoardEdge timeout and DarkXXXL ErrorContrast termination remain failures. Parent verified all101inventory image hashes/dimensions (100primary+1cleanup supplement).

T board candidate `49e3c9f`/evidence `80aec016`: status-first/shared18ptgutter/6ptgap, footer16ptshorter at bothsizes, all8capacitymethods and16matched comparisons pass. Full312methods:308passed/4failed,0skips; unchanged BoardMultiline screenshot/event timeouts, signalTERM and a43.99999999999994vs44 frame assertion. Parent verified all32before/after image hashes/dimensions and inspected default bottom.

Only R/T task evidence and immutable source patches are retained on integration, explicitly marked PARENT-STATUS pending; application candidate code is **not merged**. Both devices were restored and released. S sign-in still has its current suite; no new heavyweight suite is allowed until it finishes. Then run isolated serialized rechecks before accepting candidates.

Parent repaired only circle width/height comparisons in BoardMultilineUITests with a1e-9pt roundoff allowance, vastly below a physical pixel. The44pt target requirement and all other assertions remain. This test-only correction is not yet runtime-verified; quiet recheck must execute it and retain all initial failures. Do not attribute timeouts to host load as proven causation.
