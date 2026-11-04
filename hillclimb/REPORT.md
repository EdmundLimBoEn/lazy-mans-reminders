# Notepad UI hill climb: progress report

Work continues on hillclimb/ui. Final score gate is not reached. Round1 is the actual screenshot baseline: Sol6.88 and Astra6.70 over30 categories. Opus has not run; it is eligible only after BOTH Codex graders score >=8.5 overall in the same round. Final stop remains all three >=9 with every category >=7.

## Category scores

| Category | R1 Sol | R2 Sol | R1 Astra | R2 Astra |
| --- | ---: | ---: | ---: | ---: |
| Visual hierarchy | 7.5 | 8.5 | 7 | 8.5 |
| Spacing/grid | 7 | 8 | 7 | 8.2 |
| Typography scale | 8.5 | 8.5 | 8 | 8.5 |
| Dynamic Type | 7.5 | 7.8 | 7 | 8 |
| Light contrast | 7 | 8.2 | 7 | 8.3 |
| Dark contrast | 6.5 | 8.3 | 6.5 | 8.3 |
| Iconography | 8 | 8.4 | 8 | 8.5 |
| Safe area / Dynamic Island | 8 | 8 | 8 | 8.5 |
| Scroll/pull-down / last row | 4 | 9 | 4 | 9.2 |
| List rows | 6.5 | 7.5 | 6.5 | 7.8 |
| Empty states | 7 | 8 | 7.5 | 8.2 |
| Composer ergonomics | 6 | 8.2 | 6 | 8.6 |
| Keyboard handling | 7 | 7 | 7.5 | 7.2 |
| Sheet presentation/detents | 7 | 9 | 6 | 9 |
| Navigation clarity | 7.5 | 8.5 | 7 | 8.7 |
| Touch targets | 4.5 | 9 | 4.5 | 9 |
| Haptics | 7 | 7.5 | 7 | 7 |
| Animation/transitions | 6.5 | 7.5 | 6.5 | 7.4 |
| Loading states | 7.5 | 7.5 | 7 | 7.6 |
| Error states | 7.5 | 7.8 | 7 | 7.5 |
| VoiceOver/labels | 7.5 | 7.8 | 7.5 | 7.5 |
| iOS HIG consistency | 7.5 | 8.4 | 7 | 8.5 |
| Lock Screen / Live Activity | 6 | 7.7 | 6 | 8 |
| Sign-in/onboarding | 6.5 | 8 | 6.5 | 7.8 |
| Settings/account | 7 | 8.7 | 6 | 8.5 |
| Performance feel | 6.5 | 7.5 | 6.5 | 7.6 |
| Delight | 6.5 | 7.4 | 6.5 | 7.5 |
| Long text | 7 | 8.4 | 7 | 8.3 |
| Reduced Motion / Transparency | 7 | 8 | 6 | 8 |
| Palette / minimalism | 7 | 9.2 | 7 | 9 |

Round2: Sol8.11 and Astra8.16; each minimum7.0. Improvements are+1.23 and+1.46 respectively. Both remain below8.5, so Opus is not eligible. No third-grader result or final success is invented. [Score chart](score-progress.html).

## Screenshot evidence and comparisons

Round1 contains18 real1206x2622 screenshots in light/dark, including full/empty boards, composer, account, sign-in, long text, XXXL and bottom-after-pull. Its manifest retains a failed synthesized scroll attempt and the successful advised raw-drag recovery. Five usable Apple Reminders references are paired in rounds/1/pairs.json; Notes is unavailable in this runtime and four transitional Reminders captures are excluded. The pairs below use matching actual app states from round1 and round2 on the original17 simulator.

- [Baseline final row](rounds/1/full-light-default-bottom-after-pull.png): geometrically contained, but final ink fades beneath chrome.
- [Baseline XXXL final row](rounds/1/long-text-light-XXXL-bottom-after-pull.png).
- [Native Island after candidate fix](tasks/activity-polish/long-dark-XXXL-expanded.png): actual native recording frame, clear footer and rounded-corner clearance.
- [Native Activity banner after candidate fix](tasks/activity-polish/long-light-XXXL-notification-center.png): Notification Center, not a truly locked-device capture.

Activity task retained an intermediate candidate clipping image and recording; these are not baseline round1 evidence. See its task report and manifest for exact source/operation provenance. Unit-rendered Activity images are explicitly separate from native surface captures.

## Merged changes and verification

- Integration created from origin/main5fc4cbc; original untracked files preserved. All work stays off main and no deploy/submission/force-push occurred.
- Capture/rating infrastructure: offline isolated Debug fixtures, actual frame/height probes, repeatable capture script, reference-pair manifest and score validator. Existing247 XCTest tests passed on regular17; repaired offline fixture UI test1/1 passed. Baseline measured field22pt/Account36pt failures and a pull-idle timeout remain recorded until board fixes pass.
- Activity task dcc4200/de1ad3a: scalable typography, independent surface line budgets, native Island lower-corner clearance and existing overflow wording. Board capacity/storage/schema unchanged. Build and249 unit tests passed; native Island check1/1 at default and1/1 at XXXL. Parent inspected representative native images and verified24 capture hashes before merging.
- Board task cc98098/ef82a67/9ff1d6c merged: final-line fades removed, refresh cleanup and compact native context,44pt measured controls;253 tests passed on its branch (247 unit +6 UI), with3 additional fresh-process pull repetitions and20 verified captures. Worker evidence is supplemented by the now-passing combined suite. Sign-in04098b7/96077a3 also merged: flattened outer surfaces,44pt focus containers and keyboard scrolling;250 tests passed (247 unit+3 UI),24 settled captures verified. One invalid-frame runtime warning remains localized to the keyboard-matrix test, and the XXXL floating Done can overlap a lower secondary action; both remain explicit review concerns. Account9f94f55 merged: opaque grouped sheet, large initial/reopened detent with medium retained, safe demo scrolling/Done;249 unit+2 Account UI tests passed,16 captures verified. All four scopes are merged; combined261-test validation and round2 capture are complete, with fresh ratings complete and next fixes queued. Combined source8dbf6a8 now has261 passing tests and48 actual images; a fresh parent arm64 Release build also succeeded. Existing compiler warnings and the sign-in runtime warning remain documented.

## Next-batch accepted change

Activity overflow970f567/3020d31 is merged. Ten original lines remain ten through repeated caps (five visible+five hidden becomes three visible+seven hidden).266 iOS tests passed,8 native captures verified; parent existing Deno helper suites52/52 passed after correcting one stale expected empty-state metadata field. The legacy lines array/copy is preserved. Backend preparation changes are unshipped: no deploy was authorized or performed. Already summarized remote payloads without metadata retain their unavoidable information limit. Board-multiline and keyboard-recovery tasks still await handoff, so no new round score is claimed.

## Remaining limits

Actual device locking is unavailable through the simulator interface; Native Notification Center banner plus expanded Island recording evidence are available. Arbitrary wallpaper contrast, physical haptics and true hardware Island behavior remain unverified. Notes references remain unavailable. No dedicated quota tool was found; current-session rate-limit metadata now reports7% used in the weekly window (timestamped in rounds/2/usage.json). Stop on actual near-limit indication if available; do not wait into the next weekly window.

## Install on a phone

After final integrated verification, use hillclimb/ui, generate ios/LazyMansReminders.xcodeproj with the existing XcodeGen workflow and your existing private Config.xcconfig/development signing team. Select a connected trusted iPhone in Xcode and Build and Run. The screenshot configuration uses an isolated demo bundle/group and is not the normal account build. No upload, App Store or TestFlight step is authorized. Physical sign-in, notifications, persistence and haptics require phone validation.


## Before/after pairs: round1 to round2

| State | Before | After integrated batch |
| --- | --- | --- |
|Final row after pull|![Before](rounds/1/full-light-default-bottom-after-pull.png)|![After](rounds/2/full-light-default-bottom-after-pull.png)|
|Sign-in surfaces|![Before](rounds/1/signin-light-default-top.png)|![After](rounds/2/signin-light-default-top.png)|
|Account initial sheet|![Before](rounds/1/account-dark-default-top.png)|![After](rounds/2/account-dark-default-top.png)|
|Composer keyboard|![Before](rounds/1/composer-light-default-top.png)|![After](rounds/2/composer-light-default-top.png)|

Native Activity has fresh integrated round2 evidence; no round1 native baseline existed, so no baseline pair is invented. Current numeric after scores are the independent round2 results above.

Written by gpt-6.1-sol in Codex on behalf of Edmund

## Sign-in keyboard follow-up accepted

Task F replaces the invalid-frame InputAccessoryBar path with a layout-participating bottom inset. Done and the alternate action have48pt targets and measured separation at default/XXXL before and after scrolling.267 worker tests passed, plus2 strengthened UI rechecks.20 settled native captures verified; zero post-fix invalid-frame diagnostics. Error announcements preserve exact text and deduplicate presentations; spoken VoiceOver remains unobserved. Integrated original17 capture/regrade is pending. [Evidence](tasks/keyboard-recovery/README.md).

Written by gpt-6.1-sol in Codex on behalf of Edmund

## Board multiline and recovery follow-up accepted

Task E aligns completion/grip controls with the first text line, improves semantic icon contrast, wraps the full-capacity message, flattens the empty-board guide and hides it during composing. Existing error copy announces once per presentation; retry has a measured44pt target.265 worker tests passed;48 final-source captures verified. All E/F/G changes are merged, with integrated original17 validation and round3 grading next. [Evidence](tasks/board-multiline/README.md).

Written by gpt-6.1-sol in Codex on behalf of Edmund
