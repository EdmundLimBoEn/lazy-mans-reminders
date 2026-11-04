# Notepad UI hill climb: progress report

Work continues on `hillclimb/ui`. Round4 Codex grades are **Sol8.97** and **Astra8.95**, with minima8.1/8.2. Opus5.5/medium scored **8.51**, minimum7.6. Final stop requires all three>=9, with no category below7; it has not been reached.

## Category scores

| Category | R1 Sol | R4 Sol | R1 Astra | R4 Astra | R3 Opus | R4 Opus |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Visual hierarchy | 7.5 | 9.2 | 7 | 9.2 | 8.5 | 8.8 |
| Spacing/grid | 7.0 | 9.1 | 7 | 9.0 | 8.3 | 8.7 |
| Typography scale | 8.5 | 9.2 | 8 | 9.2 | 8.2 | 8.7 |
| Dynamic Type | 7.5 | 9.0 | 7 | 8.9 | 8.6 | 8.7 |
| Light contrast | 7.0 | 8.7 | 7 | 8.5 | 8.4 | 8.6 |
| Dark contrast | 6.5 | 9.0 | 6.5 | 8.9 | 8.0 | 8.8 |
| Iconography | 8.0 | 9.3 | 8 | 9.3 | 8.6 | 8.8 |
| Safe area / Dynamic Island | 8.0 | 9.4 | 8 | 9.2 | 8.8 | 8.8 |
| Scroll/pull-down / last row | 4.0 | 8.2 | 4 | 8.4 | 8.4 | 8.4 |
| List rows | 6.5 | 9.2 | 6.5 | 9.3 | 7.8 | 8.8 |
| Empty states | 7.0 | 9.3 | 7.5 | 9.4 | 8.8 | 8.9 |
| Composer ergonomics | 6.0 | 9.4 | 6 | 9.3 | 8.6 | 8.8 |
| Keyboard handling | 7.0 | 9.0 | 7.5 | 9.0 | 8.5 | 8.5 |
| Sheet presentation/detents | 7.0 | 9.2 | 6 | 9.2 | 8.5 | 8.7 |
| Navigation clarity | 7.5 | 9.3 | 7 | 9.3 | 8.7 | 8.8 |
| Touch targets | 4.5 | 9.5 | 4.5 | 9.4 | 8.4 | 8.8 |
| Haptics | 7.0 | 8.1 | 7 | 8.2 | 7.5 | 7.6 |
| Animation/transitions | 6.5 | 8.8 | 6.5 | 8.7 | 7.6 | 8.0 |
| Loading states | 7.5 | 9.0 | 7 | 8.8 | 8.5 | 8.6 |
| Error states | 7.5 | 8.5 | 7 | 8.5 | 7.6 | 8.0 |
| VoiceOver/labels | 7.5 | 8.6 | 7.5 | 8.6 | 8.2 | 8.2 |
| iOS HIG consistency | 7.5 | 9.2 | 7 | 9.2 | 8.1 | 8.6 |
| Lock Screen / Live Activity | 6.0 | 8.4 | 6 | 8.6 | 7.8 | 7.8 |
| Sign-in/onboarding | 6.5 | 9.1 | 6.5 | 9.0 | 8.0 | 8.6 |
| Settings/account | 7.0 | 9.1 | 6 | 9.0 | 8.1 | 8.7 |
| Performance feel | 6.5 | 8.3 | 6.5 | 8.2 | 7.6 | 7.7 |
| Delight | 6.5 | 9.0 | 6.5 | 8.8 | 7.8 | 7.9 |
| Long text | 7.0 | 9.0 | 7 | 9.0 | 8.7 | 8.7 |
| Reduced Motion / Transparency | 7.0 | 8.5 | 6 | 8.7 | 8.0 | 8.4 |
| Palette / minimalism | 7.0 | 9.6 | 7 | 9.6 | 9.0 | 9.0 |

Start/current category comparisons are shown above. Full intervening-round histories remain in their score reports. [Round4 machine-readable scores](rounds/4/scores.json).

## Current verification

Frozen production/test source: `b5d9bb3`. Round 4 passed **285/285 tests**: 263 unit and 22 UI, zero failures/skips. Fresh unsigned arm64 Debug/Release builds, 23 iOS Python checks and 52+4 offline Deno tests passed. All eight normal-settings keyboard cases completed their scrolling, clearance and edge-tap checks. Zero observed runtime warnings and invalid-frame events; other diagnostics remain retained. [Validation](validation/round4/README.md).

The original round 3 275-pass/1-failure run stays intact. A test-only correction handled supported interactive keyboard dismissal and refocus; its subsequent 276-test recheck and three repeated keyboard matrices passed. No original geometry or edge-tap assertion was disabled.

## Screenshots and Apple references

Round1 has18 native baseline images; round2 has48; round3 has110 (102 original plus8 post-scroll keyboard rechecks); round4 has288. Every grading image has device/source/hash provenance on the original regular iPhone17Pro/iOS26.2. Round3 adds8 actual XXXL Apple Reminders references for list, bottom, compose and Details in both appearances. Pairings exclude rejected transition frames and disclose imperfect matches. Notes, Apple sign-in and exact Activity equivalents remain unavailable. [Round4 inventory](rounds/4/inventory.json) · [Reference pairings](rounds/4/pairings.md).

| State | Before: round1 | Current: round4 |
| --- | --- | --- |
| Final row after pull | ![Before](rounds/1/full-light-default-bottom-after-pull.png) | ![Current](rounds/4/full-light-default-bottom-after-pull.png) |
| Sign-in surfaces | ![Before](rounds/1/signin-light-default-top.png) | ![Current](rounds/4/signin-light-default-top.png) |
| Account initial sheet | ![Before](rounds/1/account-dark-default-top.png) | ![Current](rounds/4/account-dark-default-top.png) |
| Composer keyboard | ![Before](rounds/1/composer-light-default-top.png) | ![Current](rounds/4/composer-light-default-top.png) |

Native Activity has no round1 native baseline, so no baseline pair is invented. Expanded Island evidence uses unmodified recording frames; Notification Center banners do not certify actual locked-device geometry. Unit-rendered attachments are separate from native captures.

## Merged changes

- Capture harness: repeatable offline demo fixtures, geometry/pixel checks, screenshot scripts, Apple-reference pairings and score validator.
- Board reading (`cc98098`, `ef82a67`): removed final-ink fades, fixed refresh cleanup and compact title behavior, measured44pt controls.
- Activity polish (`dcc4200`): scalable type, native surface budgets and lower-corner footer clearance.
- Sign-in surfaces (`04098b7`): flat outer surfaces,44pt field focus containers and keyboard scrolling.
- Account (`9f94f55`): opaque grouped sheet, large on open/reopen, medium retained, accessible Done and safe demo scrolling.
- Activity overflow (`970f567`, `3020d31`): preserves original line totals across payload/surface caps; five visible+five hidden becomes three visible+seven hidden. Optional metadata retains legacy lines encoding. Backend preparation is committed but undeployed; previously summarized remote payloads cannot recover lost totals.
- Keyboard recovery (`3993113`): replaces invalid-frame keyboard-toolbar path with a layout-participating48pt Done inset, separated alternate action, safe local demo editing, exact-text error announcement deduplication.
- Board multiline (`d9fa416`, `8e384d0`, `1add78a`): first-line control alignment, semantic contrast, intrinsic-height static capacity copy, flat guide hidden during composing, exact-text error announcements and44pt retry.
- Test correction (`542b9f7`): confines form scrolling above the keyboard and verifies dismissal/refocus before geometry checks.

Individual task counts and retained intermediate failures are in [task evidence](tasks). Current integrated276-test pass supersedes worker-only totals. All merges stay on `hillclimb/ui`; main, deployment, uploads and force pushes remain untouched. Existing user untracked files are preserved.

## Remaining limits

True device locking, physical cutout geometry, arbitrary wallpapers, tactile haptics, spoken VoiceOver, accessibility sizes beyondXXXL, broader system contrast/motion/transparency settings and measured motion/performance remain unverified. Source/tests support only the claims recorded with them. Current-session quota metadata reports14% used in the10080-minute weekly window; [snapshot](rounds/4/usage.json). No plateau decision before fresh grades.

## Install on a phone

1. Check out `hillclimb/ui`. Generate `ios/LazyMansReminders.xcodeproj` using the existing XcodeGen workflow and your private development `Config.xcconfig`.
2. In Xcode select your development team and a connected, trusted iPhone with Developer Mode enabled. Select the app scheme, then Build and Run.
3. Use the normal account build for real sign-in/notifications. Screenshot setup uses the isolated `systems.edmundlim.NotepadHillclimb` demo bundle/group; its offline data is synthetic.

No App Store/TestFlight upload or deployment is authorized. Physical sign-in, persistence, notifications and haptics need phone verification.

Written by gpt-6.1-sol in Codex on behalf of Edmund

Next batch: board intentional completion/Done/contrast, sign-in dark Apple control and spacing, Account typography/alignment/error announcements. Existing wording stays fixed pending the optional copy question.

## Latest integrated improvements

- Sign-in: visible native white-outline Apple button, readable help text and a 48pt Done inset with 8pt less padding. The toolbar path that produced invalid frames remains replaced. Enabled-looking provider captures are inert fixtures.
- Board: completion only on the 44pt circle, Done for nonempty drafts with text retained, unboxed readable capacity status, and populated-error retry using existing labels and full diagnostic text.
- Account: body-sized disclosure label, aligned delete-row icon/title, readable helper/footer text and exact-message error announcement deduplication. Enabled-style fixtures permit local disclosure/recovery while blocking real account and external actions.

All three branches are merged. Their individual tests and affected captures are recorded under `tasks/`; current combined acceptance uses the fresh 285-test round 4 run.

## Round 4 coverage and remaining findings

The packet contains 288 verified native PNGs, seven recordings and 17 Apple Reminders references. Selected actual-system Reduce Motion, Reduce Transparency and Increase Contrast states were captured, and the original Off settings restored. The combined-settings recording shows the alternate sign-in action, but one settled viewport omits it; a complete clearance matrix remains unproven. This is not a diagnosis of unreachability.

Top-edge fragments remain observed. New reviewer measurements find normal-size red error-message text below 4.5:1 in sign-in and Account; the existing helper/footer contrast checks excluded semantic error red. No passing error-message contrast gate is claimed. Independent Codex grades are complete. Opus8.51 confirms the loop continues; no final success is claimed.

Written by gpt-6.1-sol in Codex on behalf of Edmund

Round4 all-three reviews validate; final gate is false. Next work covers board edge/VoiceOver polish, informational text contrast, combined-settings keyboard reproduction and safe Activity readability investigation. Existing copy stays fixed.
