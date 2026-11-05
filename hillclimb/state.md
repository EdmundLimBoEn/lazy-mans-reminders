# Hill climb state

**Stopped after round 8 under the requested three-round plateau rule. The 9/10 target is unmet.** The explicit interpretation is three successive completed rounds without either Codex reviewer exceeding its previous best overall. Rounds 6–8 remain below round 5's Sol 9.06/Astra 9.15. Scores varied rather than being numerically flat; coverage and judgment changed too. See `rounds/8/plateau-audit.json`.

Integration: `hillclimb/ui`, verified source/evidence merge `4783ce10396f5bab467b22f6479d515ab89b94de`, pushed. Final reviews/report metadata are synchronized separately. No main merge, PR, force push, deployment or App Store/TestFlight operation. Original user untracked files remain untouched.

## Completed plan

1. PM directly implemented the bounded login loading/focus/composition and Account-prefix changes; no new implementation delegates.
2. Frozen source passed the serial unfiltered suite and every required programmatic gate, fresh Release/offline checks, settings restoration and installed hashes.
3. Repeatable native evidence covers all screen families in light/dark, default/XXXL and actual combined settings. Apple reference gaps remain explicit.
4. Independent Sol/high and Astra/high reviews completed:8.57/min7.5 and8.40/min7.3. Exact30categories,332canonical paths,17refs and arithmetic validate. Opus is ineligible because Astra<8.5;no Claude API/Cursor used in round8.
5. Plateau audit stops the loop. Remaining proposals are deferred in `rounds/8/followups.md`;no ungraded source edits follow the final reviews. Current weekly usage is38%,not nearly exhausted and not the stop reason.
6. Final report contains first/latest category scores, screenshot pairs, merged changes, limitations and phone-install instructions. After final remote sync,remove only the exact parent-owned keep-awake process;record actual status in `/tmp/hillclimb-awake-20261105.json`.

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
| 7 | gpt-6.1-sol | 8.50 | 7.0 |
| 7 | gpt-6-astra | 8.13 | 7.0 |
| 8 | gpt-6.1-sol | 8.57 | 7.5 |
| 8 | gpt-6-astra | 8.40 | 7.3 |


All reports use the exact30rubric categories and rounded arithmetic mean. Round6 Opus was eligible but deferred during density work to conserve Claude tokens. Rounds7–8 are ineligible;round5 remains the latest actual Opus score8.69/min7.8. No missing score is invented. Final aggregate has only the expected missing/ineligible Opus report error and `gate_passed:false`.

## Final source and validation

- App/test source `20ae77e29019444a499e9e47c98d6b656ef56819`;production revision `46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4`;source identity `sha256:a2449d961c428fc781cea0c751f3406e3e0e499350000d32bc4eca2fbfa0d76f`. All94tracked+2generated inputs match.
- **325/325 passed:263 unit+62 UI,zero failures/skips.** All317prior named IDs and transitive308/307/304/293baselines retained. Original generated arm64 xctestrun,serial,diagnosticsnever,unchanged240/300second limits.
- Fresh Debug/Release,Python23,cached Deno52+4,byte-identical Debug restoration and all six installed app/widget executable hashes pass. All five Settings-changing methods independently start/restore actual originals0/1/0/0.
- Only SignInView and BoardPersistenceSection change production this pass. Every original word, native Apple asset/provider order,auth guard,branding/icon/name remains. Loading footprint and focused heading/field clearance improve;login aesthetic acceptance remains unresolved.
-332canonical native review pictures selected from522indexed acquisitions;12unit renders separate. Sixteen native movie excerpts,16complete keyboard movie frames,8unmodified2sIsland frames,60same-state login pairs and17Reminders references. Protected secure-keyboard stills remain labeled partial. Counts do not imply distinct states or extra score credit.
- Historical322/2heading-estimate failures and323/1keyboard timeout remain failed. The timeout bypassed Settings teardown;explicit native recovery restored captured originals. Measured-heading assertions and the same eight cases split by appearance preserve requirements. No app-hang or host-load cause is invented.

Evidence: `rounds/8/checks.json`, `rounds/8/inventory.json`, `validation/round8/README.md`, `validation/round8/source-binding.json`, `tasks/login-focus-polish/acceptance.json`, `rounds/8/usage.json`. Earlier interim pending/no-plateau snapshots are historical and superseded by this final state;their raw evidence and decisions remain retained.

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
| R/S/T density candidates and U login composition | Merged after serial317/317 and parent native review | `tasks/login-composition/`, `validation/round7/` |
| Round 7 independent Codex reviews | Complete; both30categories valid; Opus ineligible | `rounds/7/` |
| Round8 PM loading/focus/composition and instruction prefixes | Merged;325/325technical pass;independent aesthetic target unmet | `tasks/login-focus-polish/`, `validation/round8/` |
| Round8 independent Codex reviews | Complete;Opus ineligible;plateau stop | `rounds/8/` |

## Remaining tasks and constraints

`rounds/8/followups.md` consolidates six deferred proposals:login hierarchy,provider boundary under Done,error association,spinner prominence,expanded guidance density and board upper-fade integration. They are not implemented or claimed passing. No active worker or reviewer remains.

Edmund's login/crowding feedback takes precedence over earlier high scores. No nested cards or decorative red/orange. Raw network-error wording explicitly stays unchanged;that question is closed. No product question is pending. Exact Cursor Opus5.5/medium remains only the authorized API-quota fallback on an eligible future round.

Physical haptics,spoken VoiceOver,true lock/wallpapers,AX1–AX5,live auth/account/AutoFill and hardware frame pacing remain unobserved. Notes and exact Apple auth/Activity/capacity/medium/combined references are missing. Public five-sample metrics are simulator/host/XCTest observations only.

## Device and host handback

Original17:host`local`,regular iPhone17Pro/iOS26.2,UDID`78F5A64F-7B2E-4562-8EF9-10F3312CC694`. Booted,light/Large,four switches0/1/0/0,owned demo Activity IDs empty. Own app/Settings terminated by native teardown;only own Device panel closed with shutdownfalse. Manual driver remained stopped on a stale prior-owner claim;no takeover or other-session closure. No Duo used.

Parent-owned Mac awake PID33824 is `/usr/bin/caffeinate -disu -t43200`,recorded in `/tmp/hillclimb-awake-20261105.json`. End it only after final sync,checking exact identity first. No global power/security settings changed;manual lock/lid closure are not overridden.

26unrelated detached automatic maintenance/pack jobs filled the disk and exited before the stop attempt.27temporary outputs/6.62GiB remain preserved;no Git object/pack file deleted,reset or repacked by PM. Repository-only `gc.auto=0` and `maintenance.auto=false` prevent recurrence;original absent values are recorded in `validation/round8/automatic-maintenance-recovery.json`. Do not re-enable while it risks the forbidden repack. No global Git config changed. Disk remains limited.

Written by gpt-6.1-sol in Codex on behalf of Edmund
