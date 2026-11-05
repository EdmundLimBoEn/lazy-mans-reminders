# Independent Astra round 2 review

Overall **8.16/10**, arithmetic mean of all 30 categories (244.7/30). Minimum **7.0**, Haptics. This is a substantial improvement from round 1 **6.70**, but does not meet the 9.0 target.

Source: `8dbf6a8e07a5b88dd6748b77a5c8030740eb5309`. Reviewed all 48 native app images and all nine usable Apple Reminders images individually. Current ratings were fixed before reading the prior Astra score; no round2 Sol review was read. No application, test, reference, device or git mutation was performed.

The most important remaining fixes are (1) separate the XXXL sign-in Done pill from the alternate sign-in action, (2) align multiline row controls to the first line, and (3) wrap the existing full-board capacity sentence. Diagnose the recurring invalid-frame warning alongside the keyboard work without presuming the two have the same cause.

## Scores

| Category | Round 2 | Round 1 | Reason |
|---|---:|---:|---|
| Visual hierarchy | 8.5 | 7.0 | Persistent compact board title, content-first list and flattened sign-in give clear hierarchy. The setup block still competes with first entry. |
| Spacing/grid | 8.2 | 7.0 | Consistent outer margins and native sheet groups; multiline row controls remain vertically centered and paragraph boundaries are tight. |
| Typography scale | 8.5 | 8.0 | Native semantic fonts and scaled Activity text establish a coherent hierarchy without decorative display styles. |
| Dynamic Type | 8.0 | 7.0 | Default and XXXL native board, form and sheet evidence is strong. Capacity placeholder still truncates; accessibility sizes beyond XXXL remain unobserved. |
| Light contrast | 8.3 | 7.0 | Primary app text is clear and final-row ink no longer fades. Disabled fixture controls are excluded from enabled-production contrast judgments; numeric and varied-wallpaper contrast evidence is absent. |
| Dark contrast | 8.3 | 6.5 | Clear primary text and opaque Account background correct the major dark defects. Thin tertiary row controls and Activity glass retain contrast uncertainty. |
| Iconography | 8.5 | 8.0 | Coherent existing SF symbols and quiet account glyphs. The remaining row issue is placement rather than symbol choice. |
| Safe area / Dynamic Island | 8.5 | 8.0 | Native app top controls and measured safe-area gates are sound; expanded Island footer clears its native bounds. Physical sensor geometry and collapsed overlay are not certified. |
| Scroll/pull-down / last row | 9.2 | 4.0 | All four bottom captures retain full final-line ink; actual pull, idle and pixel gates now pass. This is materially stronger than frame containment alone. |
| List rows | 7.8 | 6.5 | Unboxed rows, wrapping text and native collection interaction fit the product. Mid-paragraph completion circles and grips still weaken scanability relative to Reminders. |
| Empty states | 8.2 | 7.5 | Clear status and reachable composer; full XXXL instructions fit in the unfocused state. Setup guidance remains disproportionately prominent while composing. |
| Composer ergonomics | 8.6 | 6.0 | Actual 44pt focus/dismiss targets and a clean keyboard-adjacent entry field improve ergonomics. Full-board placeholder needs a wrapping display treatment. |
| Keyboard handling | 7.2 | 7.5 | Composer focus/dismiss tests pass and sign-in fields clear the keyboard. XXXL sign-in Done crowds the alternate action, and the invalid-frame runtime warning remains unresolved. |
| Sheet presentation/detents | 9.0 | 6.0 | Account opens large on an opaque grouped surface; medium/large and lower scroll states are captured and tested. Native detents now feel appropriate. |
| Navigation clarity | 8.7 | 7.0 | Your Board and count persist while scrolling; Account and Done remain obvious. Existing routes and wording are preserved. |
| Touch targets | 9.0 | 4.5 | Measured targets and padded-edge interactions pass for the board; form and Account target/bounds gates also pass. This does not establish every production action interaction. |
| Haptics | 7.0 | 7.0 | Success/error sensory feedback and drag-start selection feedback are implemented. Physical timing, intensity and comfort have not been observed; source-based credit only. |
| Animation/transitions | 7.4 | 6.5 | Native drag movement and Reduce Motion-aware board updates are present; pull idle gate passes. reloadData and still captures cannot establish animation continuity. |
| Loading states | 7.6 | 7.0 | Initial loading, retry, submission and provider busy feedback have appropriate source treatments and labels. Native busy-state evidence remains absent. |
| Error states | 7.5 | 7.0 | Native XXXL sign-in error text wraps and remains legible; board retry/banner and account recovery exist in source. Error announcement and other native failure states remain unverified. |
| VoiceOver/labels | 7.5 | 7.5 | Good row labels, states, hints, named reorder actions and success announcements. No spoken traversal/focus evidence; errors lack an explicit announcement equivalent to success. |
| iOS HIG consistency | 8.5 | 7.0 | Native navigation, grouped settings, semantic colors and restored target sizes provide a strong iOS base. Row alignment and keyboard-toolbar crowding remain visible polish gaps. |
| Lock Screen / Live Activity | 8.0 | 6.0 | Genuine native expanded and Notification Center captures show readable scaled lines and overflow footer. Expected one-line ellipses preserve bounded height; true locked, physical cutout and varied-wallpaper states remain gaps. |
| Sign-in/onboarding | 7.8 | 6.5 | Flattened provider/email form is much calmer and XXXL inbox/error variants fit. Keyboard crowding and setup prominence still prevent an effortless onboarding flow. |
| Settings/account | 8.5 | 6.0 | Opaque large Account sheet, adaptive value wrapping and reachable lower settings improve substantially. Long explanatory footer dominates at XXXL, though copy is intact and scrollable. |
| Performance feel | 7.6 | 6.5 | Finite collection, drag reload guard and now-passing pull/idle tests support responsiveness. No frame-time or real-device interaction measurement establishes premium performance feel. |
| Delight | 7.5 | 6.5 | The quiet interface is more coherent and reliable. Small alignment and keyboard collisions still interrupt the sense of finish; haptic and motion delight remain unobserved. |
| Long text | 8.3 | 7.0 | Native paragraphs wrap at default/XXXL and final ink survives bottom scrolling. Capacity placeholder ellipsis and centered multiline controls remain; Activity truncation is intentional and clearly marked. |
| Reduced Motion / Transparency | 8.0 | 6.0 | Board mutation respects Reduce Motion; composer and Account use solid surfaces and error banner offers a solid fallback. Settings-on native captures and transition behavior remain unverified. |
| Palette / minimalism | 9.0 | 7.0 | Flat monochrome board, flattened sign-in and quiet grouped Account match the requested taste. No nested cards remain; red is used for errors rather than decoration. |

## Findings

### R2A1 · P2 · XXXL sign-in with password keyboard, both appearances

Evidence: extras/signin-dark-XXXL-password-keyboard.png visibly places the floating Done pill against the final words of Use a Sign-In Link Instead; the light version is also tightly packed. SignInView uses a keyboard toolbar and scrolls only the focused field to center. Existing keyboard test asserts field clearance and Done existence, not separation from the secondary action.

Fix: Reserve the actual keyboard toolbar footprint in the form scroll layout, or position the existing Done control in an inset that participates in layout. Preserve both labels, control order and at least 44pt targets; ensure the alternate action can be fully visible without the pill covering its ink or target.

Confidence: high. Basis: observed + source-derived; no claim of failed field-clearance gate.

Regression check (proposed, not run by reviewer): Extend SignInSurfaceUITests.testFocusedEmailAndPasswordClearKeyboardInBothAppearances to scroll the secondary action into view and assert its frame does not intersect Done, with at least 8pt visual separation at default/XXXL in light/dark. Tap both exposed targets. Run the full existing iOS suite using checks.json command after rebuilding.

### R2A2 · P2 · All full and long-text board states

Evidence: full-light-default-top.png, full-dark-default-top.png and long-text-*-XXXL-*.png center circles and grips halfway down long paragraphs. The paired light/dark Reminders top/bottom references align circles near the first line. ReminderRow uses default Label alignment; ReorderableReminderList hosts a centered HStack.

Fix: Top-align the existing completion circle and reorder grip with the first line of multiline rows, preserving full text and 44pt hit regions. Give row boundaries modest vertical breathing room; avoid cards, smaller type or copy changes.

Confidence: high. Basis: observed + source-derived; remaining round1 A4.

Regression check (proposed, not run by reviewer): Add a row geometry UI case with one-, two- and twelve-line text at default/XXXL, light/dark. Assert the glyph center stays within the first-line/44pt leading band, targets remain at least 44pt and all text retains intrinsic height. Rerun all board pull, final-ink and existing iOS tests.

### R2A3 · P2 · Full-board capacity composer at XXXL

Evidence: long-text-light-XXXL-top.png and both XXXL bottom captures show Board full — combine lines i… in the disabled field. The separate hint is complete, so this is a specific status-label truncation rather than lost reminder content. ReminderListView uses an empty vertical TextField placeholder with lineLimit(1...4).

Fix: When full, show the exact existing capacity sentence as wrapping non-editable text with an equivalent accessibility label, retaining the disabled send control. Size the inset from its resulting height rather than relying on placeholder wrapping.

Confidence: high. Basis: observed + source-derived; remaining round1 A7.

Regression check (proposed, not run by reviewer): Add a capacity-label UI regression at XXXL and an accessibility text size: compare actual and intrinsic height for the complete sentence and inspect native pixels for no ellipsis. Re-run final-row ink/clearance after the inset grows and the existing iOS suite.

### R2A4 · P2 · Sign-in keyboard transition matrix

Evidence: validation/round2/combined-summary.json retains Invalid frame dimension (negative or non-finite). signin-keyboard-details.json associates it with testFocusedEmailAndPasswordClearKeyboardInBothAppearances. All assertions passed. No stack or cause is established by the screenshot or source read.

Fix: Reproduce with runtime issue breakpoints around email/password focus and keyboard presentation, locate the actual invalid frame producer, then fix its constraint or finite-size handling. Do not suppress the diagnostic or assume it is caused by the visible Done crowding.

Confidence: high for recurrence; low for cause. Basis: recorded runtime observation, not a source-proven cause or failed test.

Regression check (proposed, not run by reviewer): Repeat the existing focused-email/password light/dark default/XXXL matrix with structured runtime issues captured; require zero invalid-frame diagnostics while preserving all geometry assertions. Then rerun the unchanged full suite and retain warning output separately from pass counts.

### R2A5 · P3 · Empty board and focused empty composer, default/XXXL

Evidence: extras/composer-*-XXXL.png leaves only the setup heading and start of the first instruction visible above entry; the large empty-state illustration and spacing consume most of the available viewport. All instructions are visible unfocused in extras/empty-*-XXXL.png. Reminders empty is substantially quieter, but it has no equivalent cross-surface setup task.

Fix: Reduce the empty-state vertical footprint while the composer is focused, or move the existing setup block into a less prominent scroll position while keeping every instruction and the existing dismiss button reachable. Preserve wording and symbols; avoid new containers.

Confidence: medium-high. Basis: observed + source-derived; remaining prominence portion of round1 A8, prior fade resolved.

Regression check (proposed, not run by reviewer): Add a keyboard-open empty-board UI case that scrolls each of the three existing instruction texts fully above the composer at default/XXXL in both appearances, then dismisses the tip and refocuses entry. Check at least 44pt targets and run the existing suite.

### R2A6 · P2 · Board, sign-in and Account errors with VoiceOver

Evidence: ReminderListView.presentError changes error and errorTick; SignInView error notice clears pending and changes errorPulse; Account renders an updatesFrequently error label. Successful add/complete/reorder and check-inbox explicitly post announcements. Error labels alone do not establish an automatic spoken error or useful focus position. No VoiceOver runtime evidence was supplied.

Fix: Give newly presented errors a deliberate accessible announcement or focus policy using the existing error text, avoiding duplicate speech. Preserve focus on the relevant field or retry action when appropriate; do not add or rewrite user-facing copy.

Confidence: medium. Basis: source-derived accessibility risk; not an observed VoiceOver failure.

Regression check (proposed, not run by reviewer): Create controlled native failed-load, failed-add, sign-in failure and account-failure cases; with VoiceOver enabled verify each new error is spoken once, retry/field remains reachable, and recovery restores logical focus. Add state-level announcement policy coverage where useful and rerun existing iOS suite.

## Round 1 comparison

| Prior finding | Status | Current evidence |
|---|---|---|
| A1 bottom fade | Resolved in captured matrix | Four native bottom states retain final ink; actual pull/idle/pixel gates pass. |
| A2 undersized targets | Resolved for measured controls | Board focus/Account/dismiss targets and padded-edge interaction gates pass. |
| A3 Account translucency/medium initial detent | Resolved | Large initial opaque grouped presentation; medium remains optional; lower settings scroll capture passes. |
| A4 centered multiline controls | Remaining | R2A2. |
| A5 disappearing compact title | Resolved | Your Board and count remain in all bottom captures. |
| A6 nested sign-in cards | Resolved | Provider/email groups are flat, including XXXL inbox/error variants. |
| A7 capacity placeholder truncation | Remaining | R2A3. |
| A8 setup prominence/fading | Partly resolved | Fade removed and instructions fit unfocused; focused layout remains dominated by empty-state spacing, R2A5. |
| A9 unconditional fade/transparent Account | Source fix and default captures resolved; accessibility-settings validation remains | No custom bottom fade; solid composer and Account backgrounds. No settings-on native capture. |

Newly documented this round: R2A1 keyboard-toolbar crowding; R2A4 recurring invalid-frame runtime warning; R2A6 error-announcement risk, which is source-derived and not claimed to be a new regression. Native Activity footer evidence and form/Account expansion are new validation gains. The 30-row score table above gives every prior/current category comparison.

## Verification and source review

Read SwiftUI board/composer/row and UIKit collection bridge, SignInView, AccountView, BoardSetupTip, BoardPersistenceSection, LMRChrome, shared Activity layout and presentation, and Widget code. Reviewed related geometry/keyboard UI assertions, manifests, provenance, checks, combined summary and warnings. No test or build was run by this reviewer.

Provided run: `xcodebuild test-without-building -xctestrun /tmp/notepad-round2-dd/Build/Products/LazyMansReminders_iphonesimulator27.1-arm64.xctestrun -destination platform=iOS\ Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694 -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 180 -collect-test-diagnostics never -disableAutomaticPackageResolution -skipPackageUpdates -resultBundlePath /tmp/notepad-round2-combined.xcresult CODE_SIGNING_ALLOWED=NO`. Exact structured argv is in `checks.json` and `../../validation/round2/test-command.json`; a future run requires a fresh result bundle path and rebuilt xctestrun for changed code. Result: 249 unit +12 UI =261 passed,0 failed,0 skipped.

Gates include actual pull/idle and final-ink pixels, 44pt targets and padded-edge focus/dismiss taps, actual-versus-intrinsic text heights, Account detents/read-only scroll, sign-in bounds/keyboard, and native Island last-line clearance. These establish their assertions, not frame-rate, spoken accessibility, or tactile quality.

Fresh Release confirmation: `../../validation/round2/release-arm64-confirmation.json` records the full command, separate derived data, original simulator destination, `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`, exit0, BUILD SUCCEEDED and fresh binary. Previous unusual compiler diagnostics stay in `build-release.json` for provenance. Existing AuthManager warnings remain; the sign-in runtime invalid-frame diagnostic is not resolved.

## Image-by-image paired comparison

Each row below is an actually inspected native PNG. References are the exact nearest pair in pairings.json, not semantic equivalents where gaps are noted. No original transition_rejected reference was used.

| App image | Reference | Observation and comparison limit |
|---|---|---|
| [account-dark-default-top.png](account-dark-default-top.png) | [reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png) | Large opaque grouped sheet is calm and native; secondary values wrap at XXXL; fixture actions intentionally dim. Pair gap: Semantic gap: Account settings versus reminder Details.. |
| [account-light-default-top.png](account-light-default-top.png) | [reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png) | Large opaque grouped sheet is calm and native; secondary values wrap at XXXL; fixture actions intentionally dim. Pair gap: Semantic gap: Account settings versus reminder Details.. |
| [activity/long-dark-XXXL-expanded.png](activity/long-dark-XXXL-expanded.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Native black expanded surface has intact overflow footer and lower padding; XXXL line ellipsis is intentional. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| [activity/long-dark-XXXL-notification-center.png](activity/long-dark-XXXL-notification-center.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Native translucent banner retains overflow footer; white text reads on sampled wallpaper. Notification Center, not actual lock. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| [activity/long-light-XXXL-expanded.png](activity/long-light-XXXL-expanded.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Native black expanded surface has intact overflow footer and lower padding; XXXL line ellipsis is intentional. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| [activity/long-light-XXXL-notification-center.png](activity/long-light-XXXL-notification-center.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Native translucent banner retains overflow footer; white text reads on sampled wallpaper. Notification Center, not actual lock. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| [activity/short-dark-default-collapsed.png](activity/short-dark-default-collapsed.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Home/status pixels only; no visible collapsed overlay. Reference supports typography only, no Activity geometry. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [activity/short-dark-default-expanded.png](activity/short-dark-default-expanded.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Three readable lines plus intact +5 more footer; native rounded boundary clears text. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [activity/short-dark-default-notification-center.png](activity/short-dark-default-notification-center.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Native translucent banner retains overflow footer; white text reads on sampled wallpaper. Notification Center, not actual lock. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [activity/short-light-default-collapsed.png](activity/short-light-default-collapsed.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Home/status pixels only; no visible collapsed overlay. Reference supports typography only, no Activity geometry. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [activity/short-light-default-expanded.png](activity/short-light-default-expanded.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Three readable lines plus intact +5 more footer; native rounded boundary clears text. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [activity/short-light-default-notification-center.png](activity/short-light-default-notification-center.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Native translucent banner retains overflow footer; white text reads on sampled wallpaper. Notification Center, not actual lock. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [composer-dark-default-top.png](composer-dark-default-top.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Entry and 44pt dismiss sit cleanly above native keyboard; setup text is clipped at scroll viewport, with excessive empty-state prominence. |
| [composer-light-default-top.png](composer-light-default-top.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Entry and 44pt dismiss sit cleanly above native keyboard; setup text is clipped at scroll viewport, with excessive empty-state prominence. |
| [empty-dark-default-top.png](empty-dark-default-top.png) | [reminders-bottom-dark.png](../../reference/reminders-bottom-dark.png) | Clear empty status and complete setup instructions in unfocused state; much denser than Apple empty due to additional setup semantics. Pair gap: No exact usable state reference; No empty reference in matching appearance. |
| [empty-light-default-top.png](empty-light-default-top.png) | [reminders-empty-light.png](../../reference/reminders-empty-light.png) | Clear empty status and complete setup instructions in unfocused state; much denser than Apple empty due to additional setup semantics. Pair gap: Empty list state differs in app controls. |
| [extras/account-dark-XXXL-large-lower.png](extras/account-dark-XXXL-large-lower.png) | [reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png) | Lower actions, deletion explanation and version are reachable and fully readable; header uses normal scroll blur. Pair gap: Reference Details top differs from scrolled Account footer; Reference default type size; no exact XXXL match. |
| [extras/account-dark-XXXL-large-top.png](extras/account-dark-XXXL-large-top.png) | [reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png) | Large opaque grouped sheet is calm and native; secondary values wrap at XXXL; fixture actions intentionally dim. Pair gap: Reference default type size; no exact XXXL match. |
| [extras/account-dark-XXXL-medium-top.png](extras/account-dark-XXXL-medium-top.png) | [reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png) | Opaque optional medium sheet; dense viewport is scrollable. XXXL value moves below label when needed. Pair gap: Reference Details sheet is large; no exact medium detent match; Reference default type size; no exact XXXL match. |
| [extras/account-dark-default-medium-top.png](extras/account-dark-default-medium-top.png) | [reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png) | Opaque optional medium sheet; dense viewport is scrollable. XXXL value moves below label when needed. Pair gap: Reference Details sheet is large; no exact medium detent match. |
| [extras/account-light-XXXL-large-lower.png](extras/account-light-XXXL-large-lower.png) | [reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png) | Lower actions, deletion explanation and version are reachable and fully readable; header uses normal scroll blur. Pair gap: Reference Details top differs from scrolled Account footer; Reference default type size; no exact XXXL match. |
| [extras/account-light-XXXL-large-top.png](extras/account-light-XXXL-large-top.png) | [reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png) | Large opaque grouped sheet is calm and native; secondary values wrap at XXXL; fixture actions intentionally dim. Pair gap: Reference default type size; no exact XXXL match. |
| [extras/account-light-XXXL-medium-top.png](extras/account-light-XXXL-medium-top.png) | [reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png) | Opaque optional medium sheet; dense viewport is scrollable. XXXL value moves below label when needed. Pair gap: Reference Details sheet is large; no exact medium detent match; Reference default type size; no exact XXXL match. |
| [extras/account-light-default-medium-top.png](extras/account-light-default-medium-top.png) | [reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png) | Opaque optional medium sheet; dense viewport is scrollable. XXXL value moves below label when needed. Pair gap: Reference Details sheet is large; no exact medium detent match. |
| [extras/composer-dark-XXXL.png](extras/composer-dark-XXXL.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Entry and 44pt dismiss sit cleanly above native keyboard; setup text is clipped at scroll viewport, with excessive empty-state prominence. Pair gap: Reference default type size; no exact XXXL match. |
| [extras/composer-light-XXXL.png](extras/composer-light-XXXL.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Entry and 44pt dismiss sit cleanly above native keyboard; setup text is clipped at scroll viewport, with excessive empty-state prominence. Pair gap: Reference default type size; no exact XXXL match. |
| [extras/empty-dark-XXXL.png](extras/empty-dark-XXXL.png) | [reminders-bottom-dark.png](../../reference/reminders-bottom-dark.png) | Clear empty status and complete setup instructions in unfocused state; much denser than Apple empty due to additional setup semantics. Pair gap: No exact usable state reference; Reference default type size; no exact XXXL match; No empty reference in matching appearance. |
| [extras/empty-light-XXXL.png](extras/empty-light-XXXL.png) | [reminders-empty-light.png](../../reference/reminders-empty-light.png) | Clear empty status and complete setup instructions in unfocused state; much denser than Apple empty due to additional setup semantics. Pair gap: Reference default type size; no exact XXXL match; Empty list state differs in app controls. |
| [extras/signin-dark-XXXL-default.png](extras/signin-dark-XXXL-default.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Flat provider/email hierarchy fits cleanly; native font scale is consistent. Disabled submit appearance is fixture/state-dependent. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-dark-XXXL-error.png](extras/signin-dark-XXXL-error.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Complete error text wraps visibly at XXXL; no clipping. Red communicates error, not decoration. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-dark-XXXL-inbox.png](extras/signin-dark-XXXL-inbox.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Flat confirmation state has clear heading and complete email message; no nested card. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-dark-XXXL-password-keyboard.png](extras/signin-dark-XXXL-password-keyboard.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Focused password clears keyboard; Done crowds the alternate sign-in action, especially dark. Reference compose has distinct accessory space. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-light-XXXL-default.png](extras/signin-light-XXXL-default.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Flat provider/email hierarchy fits cleanly; native font scale is consistent. Disabled submit appearance is fixture/state-dependent. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-light-XXXL-error.png](extras/signin-light-XXXL-error.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Complete error text wraps visibly at XXXL; no clipping. Red communicates error, not decoration. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-light-XXXL-inbox.png](extras/signin-light-XXXL-inbox.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Flat confirmation state has clear heading and complete email message; no nested card. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-light-XXXL-password-keyboard.png](extras/signin-light-XXXL-password-keyboard.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Focused password clears keyboard; Done crowds the alternate sign-in action, especially dark. Reference compose has distinct accessory space. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [full-dark-default-bottom-after-pull.png](full-dark-default-bottom-after-pull.png) | [reminders-bottom-dark.png](../../reference/reminders-bottom-dark.png) | Final Demo 7 ink is fully visible above composer; persistent title/count. Centered paragraph controls remain; XXXL capacity label ellipsizes. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [full-dark-default-top.png](full-dark-default-top.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [full-light-default-bottom-after-pull.png](full-light-default-bottom-after-pull.png) | [reminders-bottom-light.png](../../reference/round2/reminders-bottom-light.png) | Final Demo 7 ink is fully visible above composer; persistent title/count. Centered paragraph controls remain; XXXL capacity label ellipsizes. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [full-light-default-top.png](full-light-default-top.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [long-text-dark-XXXL-bottom-after-pull.png](long-text-dark-XXXL-bottom-after-pull.png) | [reminders-bottom-dark.png](../../reference/reminders-bottom-dark.png) | Final Demo 7 ink is fully visible above composer; persistent title/count. Centered paragraph controls remain; XXXL capacity label ellipsizes. Pair gap: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| [long-text-dark-XXXL-top.png](long-text-dark-XXXL-top.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| [long-text-dark-default-top.png](long-text-dark-default-top.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [long-text-light-XXXL-bottom-after-pull.png](long-text-light-XXXL-bottom-after-pull.png) | [reminders-bottom-light.png](../../reference/round2/reminders-bottom-light.png) | Final Demo 7 ink is fully visible above composer; persistent title/count. Centered paragraph controls remain; XXXL capacity label ellipsizes. Pair gap: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| [long-text-light-XXXL-top.png](long-text-light-XXXL-top.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| [long-text-light-default-top.png](long-text-light-default-top.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [signin-dark-default-top.png](signin-dark-default-top.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Flat provider/email hierarchy fits cleanly; native font scale is consistent. Disabled submit appearance is fixture/state-dependent. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only. |
| [signin-light-default-top.png](signin-light-default-top.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Flat provider/email hierarchy fits cleanly; native font scale is consistent. Disabled submit appearance is fixture/state-dependent. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only. |
# Independent Astra round 2 review

Overall **8.16/10**, arithmetic mean of all 30 categories (244.7/30). Minimum **7.0**, Haptics. This is a substantial improvement from round 1 **6.70**, but does not meet the 9.0 target.

Source: `8dbf6a8e07a5b88dd6748b77a5c8030740eb5309`. Reviewed all 48 native app images and all nine usable Apple Reminders images individually. Current ratings were fixed before reading the prior Astra score; no round2 Sol review was read. No application, test, reference, device or git mutation was performed.

The most important remaining fixes are (1) separate the XXXL sign-in Done pill from the alternate sign-in action, (2) align multiline row controls to the first line, and (3) wrap the existing full-board capacity sentence. Diagnose the recurring invalid-frame warning alongside the keyboard work without presuming the two have the same cause.

## Scores

| Category | Round 2 | Round 1 | Reason |
|---|---:|---:|---|
| Visual hierarchy | 8.5 | 7.0 | Persistent compact board title, content-first list and flattened sign-in give clear hierarchy. The setup block still competes with first entry. |
| Spacing/grid | 8.2 | 7.0 | Consistent outer margins and native sheet groups; multiline row controls remain vertically centered and paragraph boundaries are tight. |
| Typography scale | 8.5 | 8.0 | Native semantic fonts and scaled Activity text establish a coherent hierarchy without decorative display styles. |
| Dynamic Type | 8.0 | 7.0 | Default and XXXL native board, form and sheet evidence is strong. Capacity placeholder still truncates; accessibility sizes beyond XXXL remain unobserved. |
| Light contrast | 8.3 | 7.0 | Primary app text is clear and final-row ink no longer fades. Disabled fixture controls are excluded from enabled-production contrast judgments; numeric and varied-wallpaper contrast evidence is absent. |
| Dark contrast | 8.3 | 6.5 | Clear primary text and opaque Account background correct the major dark defects. Thin tertiary row controls and Activity glass retain contrast uncertainty. |
| Iconography | 8.5 | 8.0 | Coherent existing SF symbols and quiet account glyphs. The remaining row issue is placement rather than symbol choice. |
| Safe area / Dynamic Island | 8.5 | 8.0 | Native app top controls and measured safe-area gates are sound; expanded Island footer clears its native bounds. Physical sensor geometry and collapsed overlay are not certified. |
| Scroll/pull-down / last row | 9.2 | 4.0 | All four bottom captures retain full final-line ink; actual pull, idle and pixel gates now pass. This is materially stronger than frame containment alone. |
| List rows | 7.8 | 6.5 | Unboxed rows, wrapping text and native collection interaction fit the product. Mid-paragraph completion circles and grips still weaken scanability relative to Reminders. |
| Empty states | 8.2 | 7.5 | Clear status and reachable composer; full XXXL instructions fit in the unfocused state. Setup guidance remains disproportionately prominent while composing. |
| Composer ergonomics | 8.6 | 6.0 | Actual 44pt focus/dismiss targets and a clean keyboard-adjacent entry field improve ergonomics. Full-board placeholder needs a wrapping display treatment. |
| Keyboard handling | 7.2 | 7.5 | Composer focus/dismiss tests pass and sign-in fields clear the keyboard. XXXL sign-in Done crowds the alternate action, and the invalid-frame runtime warning remains unresolved. |
| Sheet presentation/detents | 9.0 | 6.0 | Account opens large on an opaque grouped surface; medium/large and lower scroll states are captured and tested. Native detents now feel appropriate. |
| Navigation clarity | 8.7 | 7.0 | Your Board and count persist while scrolling; Account and Done remain obvious. Existing routes and wording are preserved. |
| Touch targets | 9.0 | 4.5 | Measured targets and padded-edge interactions pass for the board; form and Account target/bounds gates also pass. This does not establish every production action interaction. |
| Haptics | 7.0 | 7.0 | Success/error sensory feedback and drag-start selection feedback are implemented. Physical timing, intensity and comfort have not been observed; source-based credit only. |
| Animation/transitions | 7.4 | 6.5 | Native drag movement and Reduce Motion-aware board updates are present; pull idle gate passes. reloadData and still captures cannot establish animation continuity. |
| Loading states | 7.6 | 7.0 | Initial loading, retry, submission and provider busy feedback have appropriate source treatments and labels. Native busy-state evidence remains absent. |
| Error states | 7.5 | 7.0 | Native XXXL sign-in error text wraps and remains legible; board retry/banner and account recovery exist in source. Error announcement and other native failure states remain unverified. |
| VoiceOver/labels | 7.5 | 7.5 | Good row labels, states, hints, named reorder actions and success announcements. No spoken traversal/focus evidence; errors lack an explicit announcement equivalent to success. |
| iOS HIG consistency | 8.5 | 7.0 | Native navigation, grouped settings, semantic colors and restored target sizes provide a strong iOS base. Row alignment and keyboard-toolbar crowding remain visible polish gaps. |
| Lock Screen / Live Activity | 8.0 | 6.0 | Genuine native expanded and Notification Center captures show readable scaled lines and overflow footer. Expected one-line ellipses preserve bounded height; true locked, physical cutout and varied-wallpaper states remain gaps. |
| Sign-in/onboarding | 7.8 | 6.5 | Flattened provider/email form is much calmer and XXXL inbox/error variants fit. Keyboard crowding and setup prominence still prevent an effortless onboarding flow. |
| Settings/account | 8.5 | 6.0 | Opaque large Account sheet, adaptive value wrapping and reachable lower settings improve substantially. Long explanatory footer dominates at XXXL, though copy is intact and scrollable. |
| Performance feel | 7.6 | 6.5 | Finite collection, drag reload guard and now-passing pull/idle tests support responsiveness. No frame-time or real-device interaction measurement establishes premium performance feel. |
| Delight | 7.5 | 6.5 | The quiet interface is more coherent and reliable. Small alignment and keyboard collisions still interrupt the sense of finish; haptic and motion delight remain unobserved. |
| Long text | 8.3 | 7.0 | Native paragraphs wrap at default/XXXL and final ink survives bottom scrolling. Capacity placeholder ellipsis and centered multiline controls remain; Activity truncation is intentional and clearly marked. |
| Reduced Motion / Transparency | 8.0 | 6.0 | Board mutation respects Reduce Motion; composer and Account use solid surfaces and error banner offers a solid fallback. Settings-on native captures and transition behavior remain unverified. |
| Palette / minimalism | 9.0 | 7.0 | Flat monochrome board, flattened sign-in and quiet grouped Account match the requested taste. No nested cards remain; red is used for errors rather than decoration. |

## Findings

### R2A1 · P2 · XXXL sign-in with password keyboard, both appearances

Evidence: extras/signin-dark-XXXL-password-keyboard.png visibly places the floating Done pill against the final words of Use a Sign-In Link Instead; the light version is also tightly packed. SignInView uses a keyboard toolbar and scrolls only the focused field to center. Existing keyboard test asserts field clearance and Done existence, not separation from the secondary action.

Fix: Reserve the actual keyboard toolbar footprint in the form scroll layout, or position the existing Done control in an inset that participates in layout. Preserve both labels, control order and at least 44pt targets; ensure the alternate action can be fully visible without the pill covering its ink or target.

Confidence: high. Basis: observed + source-derived; no claim of failed field-clearance gate.

Regression check (proposed, not run by reviewer): Extend SignInSurfaceUITests.testFocusedEmailAndPasswordClearKeyboardInBothAppearances to scroll the secondary action into view and assert its frame does not intersect Done, with at least 8pt visual separation at default/XXXL in light/dark. Tap both exposed targets. Run the full existing iOS suite using checks.json command after rebuilding.

### R2A2 · P2 · All full and long-text board states

Evidence: full-light-default-top.png, full-dark-default-top.png and long-text-*-XXXL-*.png center circles and grips halfway down long paragraphs. The paired light/dark Reminders top/bottom references align circles near the first line. ReminderRow uses default Label alignment; ReorderableReminderList hosts a centered HStack.

Fix: Top-align the existing completion circle and reorder grip with the first line of multiline rows, preserving full text and 44pt hit regions. Give row boundaries modest vertical breathing room; avoid cards, smaller type or copy changes.

Confidence: high. Basis: observed + source-derived; remaining round1 A4.

Regression check (proposed, not run by reviewer): Add a row geometry UI case with one-, two- and twelve-line text at default/XXXL, light/dark. Assert the glyph center stays within the first-line/44pt leading band, targets remain at least 44pt and all text retains intrinsic height. Rerun all board pull, final-ink and existing iOS tests.

### R2A3 · P2 · Full-board capacity composer at XXXL

Evidence: long-text-light-XXXL-top.png and both XXXL bottom captures show Board full — combine lines i… in the disabled field. The separate hint is complete, so this is a specific status-label truncation rather than lost reminder content. ReminderListView uses an empty vertical TextField placeholder with lineLimit(1...4).

Fix: When full, show the exact existing capacity sentence as wrapping non-editable text with an equivalent accessibility label, retaining the disabled send control. Size the inset from its resulting height rather than relying on placeholder wrapping.

Confidence: high. Basis: observed + source-derived; remaining round1 A7.

Regression check (proposed, not run by reviewer): Add a capacity-label UI regression at XXXL and an accessibility text size: compare actual and intrinsic height for the complete sentence and inspect native pixels for no ellipsis. Re-run final-row ink/clearance after the inset grows and the existing iOS suite.

### R2A4 · P2 · Sign-in keyboard transition matrix

Evidence: validation/round2/combined-summary.json retains Invalid frame dimension (negative or non-finite). signin-keyboard-details.json associates it with testFocusedEmailAndPasswordClearKeyboardInBothAppearances. All assertions passed. No stack or cause is established by the screenshot or source read.

Fix: Reproduce with runtime issue breakpoints around email/password focus and keyboard presentation, locate the actual invalid frame producer, then fix its constraint or finite-size handling. Do not suppress the diagnostic or assume it is caused by the visible Done crowding.

Confidence: high for recurrence; low for cause. Basis: recorded runtime observation, not a source-proven cause or failed test.

Regression check (proposed, not run by reviewer): Repeat the existing focused-email/password light/dark default/XXXL matrix with structured runtime issues captured; require zero invalid-frame diagnostics while preserving all geometry assertions. Then rerun the unchanged full suite and retain warning output separately from pass counts.

### R2A5 · P3 · Empty board and focused empty composer, default/XXXL

Evidence: extras/composer-*-XXXL.png leaves only the setup heading and start of the first instruction visible above entry; the large empty-state illustration and spacing consume most of the available viewport. All instructions are visible unfocused in extras/empty-*-XXXL.png. Reminders empty is substantially quieter, but it has no equivalent cross-surface setup task.

Fix: Reduce the empty-state vertical footprint while the composer is focused, or move the existing setup block into a less prominent scroll position while keeping every instruction and the existing dismiss button reachable. Preserve wording and symbols; avoid new containers.

Confidence: medium-high. Basis: observed + source-derived; remaining prominence portion of round1 A8, prior fade resolved.

Regression check (proposed, not run by reviewer): Add a keyboard-open empty-board UI case that scrolls each of the three existing instruction texts fully above the composer at default/XXXL in both appearances, then dismisses the tip and refocuses entry. Check at least 44pt targets and run the existing suite.

### R2A6 · P2 · Board, sign-in and Account errors with VoiceOver

Evidence: ReminderListView.presentError changes error and errorTick; SignInView error notice clears pending and changes errorPulse; Account renders an updatesFrequently error label. Successful add/complete/reorder and check-inbox explicitly post announcements. Error labels alone do not establish an automatic spoken error or useful focus position. No VoiceOver runtime evidence was supplied.

Fix: Give newly presented errors a deliberate accessible announcement or focus policy using the existing error text, avoiding duplicate speech. Preserve focus on the relevant field or retry action when appropriate; do not add or rewrite user-facing copy.

Confidence: medium. Basis: source-derived accessibility risk; not an observed VoiceOver failure.

Regression check (proposed, not run by reviewer): Create controlled native failed-load, failed-add, sign-in failure and account-failure cases; with VoiceOver enabled verify each new error is spoken once, retry/field remains reachable, and recovery restores logical focus. Add state-level announcement policy coverage where useful and rerun existing iOS suite.

## Round 1 comparison

| Prior finding | Status | Current evidence |
|---|---|---|
| A1 bottom fade | Resolved in captured matrix | Four native bottom states retain final ink; actual pull/idle/pixel gates pass. |
| A2 undersized targets | Resolved for measured controls | Board focus/Account/dismiss targets and padded-edge interaction gates pass. |
| A3 Account translucency/medium initial detent | Resolved | Large initial opaque grouped presentation; medium remains optional; lower settings scroll capture passes. |
| A4 centered multiline controls | Remaining | R2A2. |
| A5 disappearing compact title | Resolved | Your Board and count remain in all bottom captures. |
| A6 nested sign-in cards | Resolved | Provider/email groups are flat, including XXXL inbox/error variants. |
| A7 capacity placeholder truncation | Remaining | R2A3. |
| A8 setup prominence/fading | Partly resolved | Fade removed and instructions fit unfocused; focused layout remains dominated by empty-state spacing, R2A5. |
| A9 unconditional fade/transparent Account | Source fix and default captures resolved; accessibility-settings validation remains | No custom bottom fade; solid composer and Account backgrounds. No settings-on native capture. |

Newly documented this round: R2A1 keyboard-toolbar crowding; R2A4 recurring invalid-frame runtime warning; R2A6 error-announcement risk, which is source-derived and not claimed to be a new regression. Native Activity footer evidence and form/Account expansion are new validation gains. The 30-row score table above gives every prior/current category comparison.

## Verification and source review

Read SwiftUI board/composer/row and UIKit collection bridge, SignInView, AccountView, BoardSetupTip, BoardPersistenceSection, LMRChrome, shared Activity layout and presentation, and Widget code. Reviewed related geometry/keyboard UI assertions, manifests, provenance, checks, combined summary and warnings. No test or build was run by this reviewer.

Provided run: `xcodebuild test-without-building -xctestrun /tmp/notepad-round2-dd/Build/Products/LazyMansReminders_iphonesimulator27.1-arm64.xctestrun -destination platform=iOS\ Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694 -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 180 -collect-test-diagnostics never -disableAutomaticPackageResolution -skipPackageUpdates -resultBundlePath /tmp/notepad-round2-combined.xcresult CODE_SIGNING_ALLOWED=NO`. Exact structured argv is in `checks.json` and `../../validation/round2/test-command.json`; a future run requires a fresh result bundle path and rebuilt xctestrun for changed code. Result: 249 unit +12 UI =261 passed,0 failed,0 skipped.

Gates include actual pull/idle and final-ink pixels, 44pt targets and padded-edge focus/dismiss taps, actual-versus-intrinsic text heights, Account detents/read-only scroll, sign-in bounds/keyboard, and native Island last-line clearance. These establish their assertions, not frame-rate, spoken accessibility, or tactile quality.

Fresh Release confirmation: `../../validation/round2/release-arm64-confirmation.json` records the full command, separate derived data, original simulator destination, `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`, exit0, BUILD SUCCEEDED and fresh binary. Previous unusual compiler diagnostics stay in `build-release.json` for provenance. Existing AuthManager warnings remain; the sign-in runtime invalid-frame diagnostic is not resolved.

## Image-by-image paired comparison

Each row below is an actually inspected native PNG. References are the exact nearest pair in pairings.json, not semantic equivalents where gaps are noted. No original transition_rejected reference was used.

| App image | Reference | Observation and comparison limit |
|---|---|---|
| [account-dark-default-top.png](account-dark-default-top.png) | [reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png) | Large opaque grouped sheet is calm and native; secondary values wrap at XXXL; fixture actions intentionally dim. Pair gap: Semantic gap: Account settings versus reminder Details.. |
| [account-light-default-top.png](account-light-default-top.png) | [reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png) | Large opaque grouped sheet is calm and native; secondary values wrap at XXXL; fixture actions intentionally dim. Pair gap: Semantic gap: Account settings versus reminder Details.. |
| [activity/long-dark-XXXL-expanded.png](activity/long-dark-XXXL-expanded.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Native black expanded surface has intact overflow footer and lower padding; XXXL line ellipsis is intentional. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| [activity/long-dark-XXXL-notification-center.png](activity/long-dark-XXXL-notification-center.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Native translucent banner retains overflow footer; white text reads on sampled wallpaper. Notification Center, not actual lock. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| [activity/long-light-XXXL-expanded.png](activity/long-light-XXXL-expanded.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Native black expanded surface has intact overflow footer and lower padding; XXXL line ellipsis is intentional. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| [activity/long-light-XXXL-notification-center.png](activity/long-light-XXXL-notification-center.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Native translucent banner retains overflow footer; white text reads on sampled wallpaper. Notification Center, not actual lock. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| [activity/short-dark-default-collapsed.png](activity/short-dark-default-collapsed.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Home/status pixels only; no visible collapsed overlay. Reference supports typography only, no Activity geometry. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [activity/short-dark-default-expanded.png](activity/short-dark-default-expanded.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Three readable lines plus intact +5 more footer; native rounded boundary clears text. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [activity/short-dark-default-notification-center.png](activity/short-dark-default-notification-center.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Native translucent banner retains overflow footer; white text reads on sampled wallpaper. Notification Center, not actual lock. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [activity/short-light-default-collapsed.png](activity/short-light-default-collapsed.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Home/status pixels only; no visible collapsed overlay. Reference supports typography only, no Activity geometry. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [activity/short-light-default-expanded.png](activity/short-light-default-expanded.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Three readable lines plus intact +5 more footer; native rounded boundary clears text. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [activity/short-light-default-notification-center.png](activity/short-light-default-notification-center.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Native translucent banner retains overflow footer; white text reads on sampled wallpaper. Notification Center, not actual lock. Pair gap: No native Apple Activity reference; matched list only for typography, not geometry. |
| [composer-dark-default-top.png](composer-dark-default-top.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Entry and 44pt dismiss sit cleanly above native keyboard; setup text is clipped at scroll viewport, with excessive empty-state prominence. |
| [composer-light-default-top.png](composer-light-default-top.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Entry and 44pt dismiss sit cleanly above native keyboard; setup text is clipped at scroll viewport, with excessive empty-state prominence. |
| [empty-dark-default-top.png](empty-dark-default-top.png) | [reminders-bottom-dark.png](../../reference/reminders-bottom-dark.png) | Clear empty status and complete setup instructions in unfocused state; much denser than Apple empty due to additional setup semantics. Pair gap: No exact usable state reference; No empty reference in matching appearance. |
| [empty-light-default-top.png](empty-light-default-top.png) | [reminders-empty-light.png](../../reference/reminders-empty-light.png) | Clear empty status and complete setup instructions in unfocused state; much denser than Apple empty due to additional setup semantics. Pair gap: Empty list state differs in app controls. |
| [extras/account-dark-XXXL-large-lower.png](extras/account-dark-XXXL-large-lower.png) | [reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png) | Lower actions, deletion explanation and version are reachable and fully readable; header uses normal scroll blur. Pair gap: Reference Details top differs from scrolled Account footer; Reference default type size; no exact XXXL match. |
| [extras/account-dark-XXXL-large-top.png](extras/account-dark-XXXL-large-top.png) | [reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png) | Large opaque grouped sheet is calm and native; secondary values wrap at XXXL; fixture actions intentionally dim. Pair gap: Reference default type size; no exact XXXL match. |
| [extras/account-dark-XXXL-medium-top.png](extras/account-dark-XXXL-medium-top.png) | [reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png) | Opaque optional medium sheet; dense viewport is scrollable. XXXL value moves below label when needed. Pair gap: Reference Details sheet is large; no exact medium detent match; Reference default type size; no exact XXXL match. |
| [extras/account-dark-default-medium-top.png](extras/account-dark-default-medium-top.png) | [reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png) | Opaque optional medium sheet; dense viewport is scrollable. XXXL value moves below label when needed. Pair gap: Reference Details sheet is large; no exact medium detent match. |
| [extras/account-light-XXXL-large-lower.png](extras/account-light-XXXL-large-lower.png) | [reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png) | Lower actions, deletion explanation and version are reachable and fully readable; header uses normal scroll blur. Pair gap: Reference Details top differs from scrolled Account footer; Reference default type size; no exact XXXL match. |
| [extras/account-light-XXXL-large-top.png](extras/account-light-XXXL-large-top.png) | [reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png) | Large opaque grouped sheet is calm and native; secondary values wrap at XXXL; fixture actions intentionally dim. Pair gap: Reference default type size; no exact XXXL match. |
| [extras/account-light-XXXL-medium-top.png](extras/account-light-XXXL-medium-top.png) | [reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png) | Opaque optional medium sheet; dense viewport is scrollable. XXXL value moves below label when needed. Pair gap: Reference Details sheet is large; no exact medium detent match; Reference default type size; no exact XXXL match. |
| [extras/account-light-default-medium-top.png](extras/account-light-default-medium-top.png) | [reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png) | Opaque optional medium sheet; dense viewport is scrollable. XXXL value moves below label when needed. Pair gap: Reference Details sheet is large; no exact medium detent match. |
| [extras/composer-dark-XXXL.png](extras/composer-dark-XXXL.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Entry and 44pt dismiss sit cleanly above native keyboard; setup text is clipped at scroll viewport, with excessive empty-state prominence. Pair gap: Reference default type size; no exact XXXL match. |
| [extras/composer-light-XXXL.png](extras/composer-light-XXXL.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Entry and 44pt dismiss sit cleanly above native keyboard; setup text is clipped at scroll viewport, with excessive empty-state prominence. Pair gap: Reference default type size; no exact XXXL match. |
| [extras/empty-dark-XXXL.png](extras/empty-dark-XXXL.png) | [reminders-bottom-dark.png](../../reference/reminders-bottom-dark.png) | Clear empty status and complete setup instructions in unfocused state; much denser than Apple empty due to additional setup semantics. Pair gap: No exact usable state reference; Reference default type size; no exact XXXL match; No empty reference in matching appearance. |
| [extras/empty-light-XXXL.png](extras/empty-light-XXXL.png) | [reminders-empty-light.png](../../reference/reminders-empty-light.png) | Clear empty status and complete setup instructions in unfocused state; much denser than Apple empty due to additional setup semantics. Pair gap: Reference default type size; no exact XXXL match; Empty list state differs in app controls. |
| [extras/signin-dark-XXXL-default.png](extras/signin-dark-XXXL-default.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Flat provider/email hierarchy fits cleanly; native font scale is consistent. Disabled submit appearance is fixture/state-dependent. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-dark-XXXL-error.png](extras/signin-dark-XXXL-error.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Complete error text wraps visibly at XXXL; no clipping. Red communicates error, not decoration. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-dark-XXXL-inbox.png](extras/signin-dark-XXXL-inbox.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Flat confirmation state has clear heading and complete email message; no nested card. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-dark-XXXL-password-keyboard.png](extras/signin-dark-XXXL-password-keyboard.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Focused password clears keyboard; Done crowds the alternate sign-in action, especially dark. Reference compose has distinct accessory space. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-light-XXXL-default.png](extras/signin-light-XXXL-default.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Flat provider/email hierarchy fits cleanly; native font scale is consistent. Disabled submit appearance is fixture/state-dependent. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-light-XXXL-error.png](extras/signin-light-XXXL-error.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Complete error text wraps visibly at XXXL; no clipping. Red communicates error, not decoration. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-light-XXXL-inbox.png](extras/signin-light-XXXL-inbox.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Flat confirmation state has clear heading and complete email message; no nested card. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [extras/signin-light-XXXL-password-keyboard.png](extras/signin-light-XXXL-password-keyboard.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Focused password clears keyboard; Done crowds the alternate sign-in action, especially dark. Reference compose has distinct accessory space. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| [full-dark-default-bottom-after-pull.png](full-dark-default-bottom-after-pull.png) | [reminders-bottom-dark.png](../../reference/reminders-bottom-dark.png) | Final Demo 7 ink is fully visible above composer; persistent title/count. Centered paragraph controls remain; XXXL capacity label ellipsizes. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [full-dark-default-top.png](full-dark-default-top.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [full-light-default-bottom-after-pull.png](full-light-default-bottom-after-pull.png) | [reminders-bottom-light.png](../../reference/round2/reminders-bottom-light.png) | Final Demo 7 ink is fully visible above composer; persistent title/count. Centered paragraph controls remain; XXXL capacity label ellipsizes. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [full-light-default-top.png](full-light-default-top.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [long-text-dark-XXXL-bottom-after-pull.png](long-text-dark-XXXL-bottom-after-pull.png) | [reminders-bottom-dark.png](../../reference/reminders-bottom-dark.png) | Final Demo 7 ink is fully visible above composer; persistent title/count. Centered paragraph controls remain; XXXL capacity label ellipsizes. Pair gap: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| [long-text-dark-XXXL-top.png](long-text-dark-XXXL-top.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| [long-text-dark-default-top.png](long-text-dark-default-top.png) | [reminders-top-dark.png](../../reference/round2/reminders-top-dark.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [long-text-light-XXXL-bottom-after-pull.png](long-text-light-XXXL-bottom-after-pull.png) | [reminders-bottom-light.png](../../reference/round2/reminders-bottom-light.png) | Final Demo 7 ink is fully visible above composer; persistent title/count. Centered paragraph controls remain; XXXL capacity label ellipsizes. Pair gap: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| [long-text-light-XXXL-top.png](long-text-light-XXXL-top.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| [long-text-light-default-top.png](long-text-light-default-top.png) | [reminders-top-light.png](../../reference/reminders-top-light.png) | Paragraphs retain complete wrapping and consistent margins; controls sit mid-paragraph unlike first-line circles in reference. Pair gap: Seeded app paragraphs differ from shorter reference reminder content. |
| [signin-dark-default-top.png](signin-dark-default-top.png) | [reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png) | Flat provider/email hierarchy fits cleanly; native font scale is consistent. Disabled submit appearance is fixture/state-dependent. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only. |
| [signin-light-default-top.png](signin-light-default-top.png) | [reminders-compose-light.png](../../reference/reminders-compose-light.png) | Flat provider/email hierarchy fits cleanly; native font scale is consistent. Disabled submit appearance is fixture/state-dependent. Pair gap: No Apple sign-in reference; compose compares native form/keyboard treatment only. |

## Evidence gaps and limits

- Apple Notes remains unavailable; no Notes parity is claimed. Four original transition_rejected Reminders images were excluded; four new settled round2 references replace their missing state comparisons.
- Every app state was compared with its pairings.json reference, but no exact Apple sign-in or Activity reference exists. Account versus item Details differs semantically; medium detents, scrolled Account footer, dark empty state and all XXXL states lack exact counterparts. Board reminder content is much longer than the reference content.
- 48 actual native images were inspected individually through view_image. Ten are native Activity evidence: expanded PNGs are unmodified video frames; Notification Center is not a truly locked-device capture. Collapsed stills omit the Island overlay and show home/status state only. No physical cutout certification is inferred.
- Twelve rendered-unit Activity attachments are not native surface screenshots and were not counted among the 48. This review inspected the still PNGs, not motion playback.
- Offline fixtures intentionally disable authentication and Account actions and dim their controls. These pixels do not measure enabled-production contrast or establish real authentication, destructive actions, networking or recovery interaction.
- No native initial-loading, submission-busy, board/account-error, successful-authentication, Reduce Motion/Transparency-on, increased-contrast or accessibility-size-beyond-XXXL capture set is available.
- No direct VoiceOver traversal, spoken announcements, focus retention, physical haptics, animation continuity or measured frame-time evidence. Scores for those categories grant only supported source/test credit.
- Activity clear-glass contrast is sampled on one wallpaper in two appearances, not certified across arbitrary wallpaper or true locked-device conditions. One-line Activity ellipses are expected truncation, not a claim of full long-text visibility.
- Capture manifests say dirty=true; source SHA and production hashes are recorded in inventory/provenance. Parent verified production sources match 8dbf6a8e07a5b88dd6748b77a5c8030740eb5309; later changes are artifacts/scripts/docs. Reviewer did not run builds or device tests.
- 261 existing tests passed (249 unit,12 UI), zero failed/skipped. Runtime invalid-frame warning remains unresolved. Original Release exit-zero/no-output diagnostics remain recorded; fresh arm64-only Release confirmation exited zero, reports BUILD SUCCEEDED and produced a fresh binary, resolving that build concern. Neither run is described as warning-free.

Written by gpt-6-astra in Codex on behalf of Edmund
