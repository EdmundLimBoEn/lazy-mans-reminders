# Independent round2 review — gpt-6.1-sol

Overall **8.11/10**; minimum category **7.0** (Keyboard handling). Arithmetic mean of all30 categories. Round1 was6.88; increase **1.23**. The9.0 overall target is not met. Scores are quality judgments, with provisional limits explicitly noted; passing tests do not imply native polish in unseen behaviors.

Captured production source: `8dbf6a8e07a5b88dd6748b77a5c8030740eb5309`. I formed all current ratings before reading my round1 report; I did not read the round2 Astra report. Reviewer-only: no app/test/source edits, device operations, git changes or new runtime checks.

## Categories

| Category | Round1 | Round2 | Change | Rationale |
|---|---:|---:|---:|---|
| Visual hierarchy | 7.5 | 8.5 | +1.0 | Persistent inline board title/count, readable body and restrained primary actions establish a coherent hierarchy. The empty guide remains disproportionately prominent. |
| Spacing/grid | 7.0 | 8.0 | +1.0 | Consistent outer gutters and native grouped settings work well. Paragraph-centered row controls and the sign-in keyboard accessory collision reduce precision. |
| Typography scale | 8.5 | 8.5 | +0.0 | System text styles preserve clear title/body/helper relationships in both appearances. Main reminder paragraphs stay full size; the capacity placeholder still ellipsizes at XXXL. |
| Dynamic Type | 7.5 | 7.8 | +0.3 | Native XXXL board, sign-in, guide and account evidence now exists and text-height gates pass. Capacity-message truncation and keyboard crowding remain; larger accessibility sizes are not native-screen certified. |
| Light contrast | 7.0 | 8.2 | +1.2 | Main text and final-row ink remain crisp on semantic white surfaces. Helpers are quiet; disabled fixture controls and disabled capacity input are not enabled-production contrast failures. No numerical contrast audit was performed. |
| Dark contrast | 6.5 | 8.3 | +1.8 | White board text and final-row ink are strong on black; dark sheet separation is stable. Native Activity text is readable on the captured wallpaper. Disabled fixture dimming is excluded from enabled-control judgments. |
| Iconography | 8.0 | 8.4 | +0.4 | Preserved SF Symbols, restrained indigo setup icons and monochrome navigation are coherent. Circle/grip placement beside long paragraphs still weakens association with the task beginning. |
| Safe area / Dynamic Island | 8.0 | 8.0 | +0.0 | Actual top-control safe-area assertions pass and native expanded footer frames fit. Collapsed stills omit the overlay and neither screenshots nor simulator frames certify physical sensor-cutout geometry. |
| Scroll/pull-down / last row | 4.0 | 9.0 | +5.0 | Real pull/settled-bottom tests now pass with final-text bounds and pixel ink in both appearances, including XXXL. All four bottom captures retain crisp final text above the composer. |
| List rows | 6.5 | 7.5 | +1.0 | Plain separators, native virtualization and full wrapping are sound. Completion circles and persistent grips remain vertically centered many lines below the beginning of long tasks. |
| Empty states | 7.0 | 8.0 | +1.0 | All Clear and the permanent composer communicate the next action; all three setup instructions fit at XXXL. The large guide competes with the empty result and is left as clipped fragments during composition. |
| Composer ergonomics | 6.0 | 8.2 | +2.2 | Actual 44pt field/add/dismiss geometry and focus/dismiss interaction now pass, with bottom anchoring above the keyboard. Disabled capacity text remains truncated at XXXL. |
| Keyboard handling | 7.0 | 7.0 | +0.0 | Focused email/password and composer clear the keyboard in measured tests. XXXL sign-in Done crowds or overlaps the lower secondary action, and an invalid-frame runtime warning recurs. |
| Sheet presentation/detents | 7.0 | 9.0 | +2.0 | Account opens large, moves to medium and back, scrolls all actions, dismisses with Done and reopens large in the tested default/XXXL light/dark matrix. Stable semantic grouped backgrounds match native surface discipline. |
| Navigation clarity | 7.5 | 8.5 | +1.0 | Your Board/count persist at top and bottom; Account and Done are direct and native. Sign-in alternatives remain clear, although their keyboard-adjacent placement needs refinement. |
| Touch targets | 4.5 | 9.0 | +4.5 | Measured board, composer and account targets now meet 44pt, with actual edge taps, focus and dismissal gates. Sign-in control bounds are tested; simultaneous action/accessory separation is still missing. |
| Haptics | 7.0 | 7.5 | +0.5 | Source triggers success/error feedback after operations and selection feedback on drag start. Physical perception, timing and duplicate-event behavior remain unobserved; this is a provisional implementation score. |
| Animation/transitions | 6.5 | 7.5 | +1.0 | Short board transitions respect Reduce Motion and the earlier idle timeout is resolved by the full passing suite. UIKit reloadData continuity and actual motion quality were not observed in a reviewer interaction session. |
| Loading states | 7.5 | 7.5 | +0.0 | Source has initial loading, retry progress, completion and submit progress with duplicate-operation guards. Native loading layouts and delayed-network timing are still uncaptured. |
| Error states | 7.5 | 7.8 | +0.3 | Native XXXL auth error wraps fully with recovery guidance. Initial-board, populated-board and account failure surfaces exist in source but are uncaptured; error announcement/focus behavior needs runtime validation. |
| VoiceOver/labels | 7.5 | 7.8 | +0.3 | Source supplies explicit labels, reorder actions/positions, completion announcements and inbox announcement. Actual traversal/focus after reloads and failure announcement are unobserved; updatesFrequently alone does not prove an error is announced. |
| iOS HIG consistency | 7.5 | 8.4 | +0.9 | System navigation, grouped sheets, native keyboards and plain collection rows now have appropriate measured targets. Keyboard accessory crowding and paragraph-centered controls remain below native polish. |
| Lock Screen / Live Activity | 6.0 | 7.7 | +1.7 | New native expanded and Notification Center banners show readable text and intact overflow footer at default/XXXL. Source can undercount hidden lines when an already summarized payload is capped again; true lock, arbitrary wallpaper and physical geometry remain unverified. |
| Sign-in/onboarding | 6.5 | 8.0 | +1.5 | Unboxed sections remove the previous nested-card problem. Provider/email/password/inbox/error layouts are clearer and wrap at XXXL; keyboard accessory collision and oversized in-board guidance remain. |
| Settings/account | 7.0 | 8.7 | +1.7 | Native grouped Account is stable at both detents and lower actions/footer are reachable at XXXL. Useful status/value alignment and confirmations are present; actual enabled network/destructive workflows were intentionally not exercised. |
| Performance feel | 6.5 | 7.5 | +1.0 | The combined suite reaches idle after real pulls and all 261 tests pass; native virtualization and operation guards are sensible. No frame-time, launch-time or perceived interaction recording was assessed, so this is provisional. |
| Delight | 6.5 | 7.4 | +0.9 | The quiet monochrome board, legible final line and stable compact context feel more precise. Misaligned paragraph controls, capacity ellipsis and keyboard crowding remain conspicuous small rough edges; tactile delight is unobserved. |
| Long text | 7.0 | 8.4 | +1.4 | Actual-vs-intrinsic reminder height and final-ink gates now pass; XXXL account, error and inbox text remain readable. Capacity-placeholder completeness and Activity summary-count composition remain unresolved. |
| Reduced Motion / Transparency | 7.0 | 8.0 | +1.0 | Source gates explicit board/tip animations and uses solid composer/error alternatives; unconditional bottom fading has been removed. Real accessibility-setting interaction across app and Activity surfaces is unobserved. |
| Palette / minimalism | 7.0 | 9.2 | +2.2 | Monochrome board and account, restrained indigo actions, and flattened sign-in honor the requested clean direction. Red is confined to an actual error state; existing wording, branding and icons are preserved. |

## Findings and smallest high-impact tasks

Implement in this order: (1) reserve keyboard-accessory space and independently hit-test the secondary action, (2) wrap the exact capacity message, (3) align paragraph controls to the first line. Follow with production overflow-count composition and invalid-frame isolation. Guide restraint and VoiceOver failure routing remain smaller polish/validation work. Preserve EVERY existing user-facing word, name, brand, icon and app identity; no decorative red/orange or nested-card additions. Red error semantics may remain.

### SOL2-01 — medium

Screen: `extras/signin-light-XXXL-password-keyboard.png; extras/signin-dark-XXXL-password-keyboard.png`.

Evidence: The floating Done accessory sits immediately against the lower Use a Sign-In Link Instead action; in dark appearance its upper-left edge overlaps the action’s lower-right text region. Paired Reminders compose references have a dedicated accessory band, but differ semantically and use default type. SignInView.swift scrolls only the focused field to center; current keyboard test checks field maxY and existence of Done, not accessory/action separation.

Fix: Reserve a real keyboard-accessory inset or scroll the entire email/password action group above the accessory. Keep Done and Use a Sign-In Link Instead, all icons and wording unchanged; retain at least 44pt hit regions.

Confidence: high. Basis: observed + source-derived coverage gap; exact layout cause not isolated.

Executable acceptance check: Extend SignInSurfaceUITests/testFocusedEmailAndPasswordClearKeyboardInBothAppearances with settled default/XXXL email/password states in both appearances: assert secondary-action frame does not intersect Done or keyboard, leaves an optical gap, and can be edge-tapped independently. Tap Done and require keyboard dismissal. Run all existing iOS tests.

### SOL2-02 — medium

Screen: `long-text-light-XXXL-top.png; long-text-dark-XXXL-top.png; both XXXL bottom-after-pull captures`.

Evidence: Capacity field visibly reads Board full — combine lines i… at XXXL. Reminder text-height tests cover reminder labels, not this placeholder. The field uses a multiline TextField but its placeholder remains an ellipsized single line; same-size Apple reference is absent.

Fix: When at capacity render the exact existing Board full — combine lines instead text as an intrinsic-height wrapping label in the disabled composer treatment. Preserve the separate hint, wording and add glyph; do not shrink the type.

Confidence: high. Basis: observed + source-derived.

Executable acceptance check: Add a native capacity-message geometry/raster check at XXXL and accessibility sizes in light/dark: full exact string must wrap without ellipsis or clipping, allocated height must meet intrinsic height, and final-row ink must still clear the expanded composer. Keep current 44pt and final-ink gates; run existing suite.

### SOL2-03 — medium

Screen: `full-light-default-top.png; full-dark-default-top.png; long-text-light-XXXL-top.png; long-text-dark-XXXL-top.png`.

Evidence: Circles and six-dot grips remain near paragraph centers, several lines below each task beginning. The paired native Reminders top images align completion circles with first-line regions. The source Label and hosting HStack retain default center alignment; app fixture paragraphs are substantially longer than the Apple tasks.

Fix: Top-align the existing completion-circle and drag-grip containers to the first-line region with a consistent optical inset. Keep the exact symbols, wording, full text height and at least 44pt target geometry.

Confidence: high. Basis: observed + source-derived.

Executable acceptance check: Capture one-line, three-line and twelve-line rows at default/XXXL in both appearances. Assert control centers align with first-line region rather than paragraph midpoint, targets remain at least 44pt, and completion/reorder gestures and accessibility Move up/Move down still work. Run existing suite.

### SOL2-04 — low

Screen: `empty-light-default-top.png; empty-dark-default-top.png; extras/empty-light-XXXL.png; extras/empty-dark-XXXL.png; all composer captures`.

Evidence: The setup guide dominates the lower empty canvas; keyboard-focused composer captures leave only partial first/second instruction fragments directly above the field. Empty-light Reminders is far quieter, although it has no equivalent setup instructions. The app guide is scrollable and dismissible, so the clipped viewport is not proof that text is unreachable.

Fix: Retain every existing instruction and Dismiss tip action, but reduce the guide’s initial visual weight and move it wholly out of the focused-composer viewport while the keyboard is visible; restore it when focus ends unless permanently dismissed. Avoid adding nested cards or new copy.

Confidence: medium-high. Basis: observed + source-derived; severity is visual hierarchy, not data loss.

Executable acceptance check: Capture first-empty, dismissed-empty and focused/unfocused composer at default/XXXL in light/dark. Verify every instruction remains reachable when appropriate, dismissal persists, and keyboard focus never leaves a severed instruction fragment adjacent to composer. Run BoardSetupTip tests and existing suite.

### SOL2-05 — medium

Screen: `Source: ios/Shared/ReminderAttributes.swift lines(from:), surfaceLines(_:limit:), capped(_:limit:); ios/Shared/LockScreenLineBudget.swift ReminderActivityLinesView`.

Evidence: Production lines(from:) first caps flattened reminder lines and can insert +N more. ReminderActivityLinesView later calls surfaceLines, which caps that array again and counts the prior summary as one line. Example: five visible lines plus +5 more, capped to four rows, yields three visible lines plus +3 more although seven original lines are hidden. Multiline reminders can reach this path within the board’s reminder-count limit. Native Activity fixtures inject eight raw lines directly, so their correct +5/+6 footers do not cover this case.

Fix: Preserve the total hidden-line count as structured presentation data through payload and surface caps, or otherwise make repeated capping account for an existing summary without treating user text as metadata. Keep the exact +N more wording and all visible reminder text unchanged.

Confidence: high. Basis: source-derived conditional defect; not observed in the eight-raw-line capture fixture; no new test executed by reviewer.

Executable acceptance check: Add a production-pipeline regression using multiline Reminder values: after payload cap and smaller island/lock-screen cap, assert displayed original lines plus hidden count equals total flattened originals. Include the five-visible-plus-five-hidden then limit-four example expecting +7 more. Keep payload <=4096 bytes, Unicode cases, native footer geometry and existing 261-test suite.

### SOL2-06 — medium

Screen: `Sign-in keyboard matrix; ../../validation/round2/combined-summary.json and signin-keyboard-details.json`.

Evidence: Invalid frame dimension (negative or non-finite) recurred once in testFocusedEmailAndPasswordClearKeyboardInBothAppearances. The test passed; the warning is unresolved and is separate from assertion results. No captured still proves a negative-frame visual failure, and the precise originating view is not isolated.

Fix: Isolate the warning during keyboard show/focus scrolling and correct the non-finite/negative layout proposal at its source without suppressing the diagnostic or changing any copy. Keep the actual field/keyboard and action separation checks.

Confidence: high for warning occurrence; medium for user-visible impact. Basis: observed structured runtime diagnostic; causal attribution unconfirmed.

Executable acceptance check: Run the complete sign-in default/XXXL, light/dark email/password keyboard matrix with runtime issue collection and require zero invalid-frame diagnostics alongside all geometry assertions. Repeat transitions enough to reproduce the prior warning and record command/source SHA. Run existing suite.

### SOL2-07 — low

Screen: `Source: SignInView.swift auth.notice observer; ReminderListView.swift presentError/BoardErrorBanner; AccountView.swift error section`.

Evidence: Success/inbox and reminder completion explicitly post announcements; new auth and board/account errors rely on updatesFrequently traits and haptics. That is insufficient evidence that a user whose VoiceOver focus remains in an input hears the new failure. No VoiceOver session was supplied, so missed announcement is a risk, not an observed accessibility failure.

Fix: Use a deliberate announcement or accessible focus policy for newly presented errors while retaining existing error wording and avoiding duplicate announcements. Keep the user’s editing context when recovery is local.

Confidence: medium. Basis: source-derived; VoiceOver runtime unobserved.

Executable acceptance check: With VoiceOver enabled, trigger first-load, populated-board, auth and account errors from a controlled offline fixture. Require the existing error text to be announced once and recovery control reachable in a predictable order; verify focus after retry, list reload and sheet dismissal. Run existing suite.

## Round1 comparison

Resolved: SOL-01 final-line fade is removed and actual pull/idle/final-ink gates pass. SOL-02 measured sub44 controls are repaired, with actual focus/dismiss interaction. SOL-04 lost board title/count is repaired by persistent inline navigation. SOL-05 nested sign-in cards are gone. SOL-06 Account now opens large with stable grouped background and measured detent/lower-action coverage. SOL-09 unconditional bottom gradient is removed; actual accessibility-setting behavior remains a gap.

Remaining: SOL-03 centered paragraph controls, SOL-07 truncated XXXL capacity text and SOL-08 dominant/partially visible onboarding guide correspond to SOL2-03, SOL2-02 and SOL2-04. Existing haptic, animation, VoiceOver and native loading/error limitations remain provisional. Newly exposed: SOL2-01 large-type sign-in accessory crowding, SOL2-05 repeated summary undercount and SOL2-06 recurring invalid-frame diagnostic. SOL2-07 specifies the remaining failure-announcement risk. Native Activity and lower Account evidence close substantial former gaps without certifying true lock/hardware, widget or physical interaction behavior.

## Every native state compared to its nearest paired reference

All48 inventory PNGs were individually opened with view_image, as were all9 usable references. No rejected transition reference was opened. Reference mapping follows pairings.json exactly. An empty gaps array is not an exact semantic match: Account is still Account versus item Details, and app composer is a separate input versus Apple inline list creation. All app/reference captures share regular-device resolution; type-size and content mismatches are listed explicitly.

| App image inspected | Paired reference inspected | Direct comparison and mismatch |
|---|---|---|
| `account-dark-default-top.png` | `../../reference/reminders-sheet-dark.png` | Stable native grouped rows and clear Done match sheet discipline; app Account semantics differ from Apple item Details. Large opening is coherent and quieter than round1. Mismatches: Account versus item Details, both large/default type. |
| `account-light-default-top.png` | `../../reference/round2/reminders-sheet-light.png` | Stable native grouped rows and clear Done match sheet discipline; app Account semantics differ from Apple item Details. Large opening is coherent and quieter than round1. Mismatches: Account versus item Details, both large/default type. |
| `activity/long-dark-XXXL-expanded.png` | `../../reference/round2/reminders-top-dark.png` | Native expanded black pill has readable white rows and intact overflow footer; long XXXL rows intentionally ellipsize. Paired Reminders list only supports text/palette comparison, not native-surface geometry; app has no matching Apple Activity reference. Mismatches: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| `activity/long-dark-XXXL-notification-center.png` | `../../reference/round2/reminders-top-dark.png` | Native Notification Center banner has readable rows and overflow footer; it is not a truly locked device. Paired Reminders list only supports text/palette comparison, not native-surface geometry; app has no matching Apple Activity reference. Mismatches: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| `activity/long-light-XXXL-expanded.png` | `../../reference/reminders-top-light.png` | Native expanded black pill has readable white rows and intact overflow footer; long XXXL rows intentionally ellipsize. Paired Reminders list only supports text/palette comparison, not native-surface geometry; app has no matching Apple Activity reference. Mismatches: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| `activity/long-light-XXXL-notification-center.png` | `../../reference/reminders-top-light.png` | Native Notification Center banner has readable rows and overflow footer; it is not a truly locked device. Paired Reminders list only supports text/palette comparison, not native-surface geometry; app has no matching Apple Activity reference. Mismatches: No native Apple Activity reference; matched list only for typography, not geometry; Reference default type size; no exact XXXL match. |
| `activity/short-dark-default-collapsed.png` | `../../reference/round2/reminders-top-dark.png` | Home/status state is clear; Island overlay is omitted from the still, so no compact geometry judgment is possible. Paired Reminders list only supports text/palette comparison, not native-surface geometry; app has no matching Apple Activity reference. Mismatches: No native Apple Activity reference; matched list only for typography, not geometry. |
| `activity/short-dark-default-expanded.png` | `../../reference/round2/reminders-top-dark.png` | Native expanded black pill has three readable rows and intact +5 more footer. Paired Reminders list only supports text/palette comparison, not native-surface geometry; app has no matching Apple Activity reference. Mismatches: No native Apple Activity reference; matched list only for typography, not geometry. |
| `activity/short-dark-default-notification-center.png` | `../../reference/round2/reminders-top-dark.png` | Native Notification Center banner has readable rows and overflow footer; it is not a truly locked device. Paired Reminders list only supports text/palette comparison, not native-surface geometry; app has no matching Apple Activity reference. Mismatches: No native Apple Activity reference; matched list only for typography, not geometry. |
| `activity/short-light-default-collapsed.png` | `../../reference/reminders-top-light.png` | Home/status state is clear; Island overlay is omitted from the still, so no compact geometry judgment is possible. Paired Reminders list only supports text/palette comparison, not native-surface geometry; app has no matching Apple Activity reference. Mismatches: No native Apple Activity reference; matched list only for typography, not geometry. |
| `activity/short-light-default-expanded.png` | `../../reference/reminders-top-light.png` | Native expanded black pill has three readable rows and intact +5 more footer. Paired Reminders list only supports text/palette comparison, not native-surface geometry; app has no matching Apple Activity reference. Mismatches: No native Apple Activity reference; matched list only for typography, not geometry. |
| `activity/short-light-default-notification-center.png` | `../../reference/reminders-top-light.png` | Native Notification Center banner has readable rows and overflow footer; it is not a truly locked device. Paired Reminders list only supports text/palette comparison, not native-surface geometry; app has no matching Apple Activity reference. Mismatches: No native Apple Activity reference; matched list only for typography, not geometry. |
| `composer-dark-default-top.png` | `../../reference/round2/reminders-compose-dark.png` | Separate composer clears native keyboard and exposes a dismiss control; setup-guide fragments occupy content edge. Apple composes inline in populated list with a dedicated accessory strip. Mismatches: Different seeded/empty composition content and creation layout. |
| `composer-light-default-top.png` | `../../reference/reminders-compose-light.png` | Separate composer clears native keyboard and exposes a dismiss control; setup-guide fragments occupy content edge. Apple composes inline in populated list with a dedicated accessory strip. Mismatches: Different seeded/empty composition content and creation layout. |
| `empty-dark-default-top.png` | `../../reference/reminders-bottom-dark.png` | All Clear and dark guide are readable; paired Apple populated bottom is a palette/list proxy, not an empty-state match. Mismatches: No exact usable state reference; No empty reference in matching appearance. |
| `empty-light-default-top.png` | `../../reference/reminders-empty-light.png` | All Clear and exact setup instructions are readable, but much more visually prominent than quiet Apple empty canvas. Mismatches: Empty list state differs in app controls. |
| `extras/account-dark-XXXL-large-lower.png` | `../../reference/reminders-sheet-dark.png` | Stable native grouped rows and clear Done match sheet discipline; app Account semantics differ from Apple item Details. All lower actions/footer are readable after scroll; Apple shows top form content. Mismatches: Reference Details top differs from scrolled Account footer; Reference default type size; no exact XXXL match. |
| `extras/account-dark-XXXL-large-top.png` | `../../reference/reminders-sheet-dark.png` | Stable native grouped rows and clear Done match sheet discipline; app Account semantics differ from Apple item Details. Large opening is coherent and quieter than round1. Mismatches: Reference default type size; no exact XXXL match. |
| `extras/account-dark-XXXL-medium-top.png` | `../../reference/reminders-sheet-dark.png` | Stable native grouped rows and clear Done match sheet discipline; app Account semantics differ from Apple item Details. App uses a shorter medium viewport; Apple is large. Mismatches: Reference Details sheet is large; no exact medium detent match; Reference default type size; no exact XXXL match. |
| `extras/account-dark-default-medium-top.png` | `../../reference/reminders-sheet-dark.png` | Stable native grouped rows and clear Done match sheet discipline; app Account semantics differ from Apple item Details. App uses a shorter medium viewport; Apple is large. Mismatches: Reference Details sheet is large; no exact medium detent match. |
| `extras/account-light-XXXL-large-lower.png` | `../../reference/round2/reminders-sheet-light.png` | Stable native grouped rows and clear Done match sheet discipline; app Account semantics differ from Apple item Details. All lower actions/footer are readable after scroll; Apple shows top form content. Mismatches: Reference Details top differs from scrolled Account footer; Reference default type size; no exact XXXL match. |
| `extras/account-light-XXXL-large-top.png` | `../../reference/round2/reminders-sheet-light.png` | Stable native grouped rows and clear Done match sheet discipline; app Account semantics differ from Apple item Details. Large opening is coherent and quieter than round1. Mismatches: Reference default type size; no exact XXXL match. |
| `extras/account-light-XXXL-medium-top.png` | `../../reference/round2/reminders-sheet-light.png` | Stable native grouped rows and clear Done match sheet discipline; app Account semantics differ from Apple item Details. App uses a shorter medium viewport; Apple is large. Mismatches: Reference Details sheet is large; no exact medium detent match; Reference default type size; no exact XXXL match. |
| `extras/account-light-default-medium-top.png` | `../../reference/round2/reminders-sheet-light.png` | Stable native grouped rows and clear Done match sheet discipline; app Account semantics differ from Apple item Details. App uses a shorter medium viewport; Apple is large. Mismatches: Reference Details sheet is large; no exact medium detent match. |
| `extras/composer-dark-XXXL.png` | `../../reference/round2/reminders-compose-dark.png` | Separate composer clears native keyboard and exposes a dismiss control; setup-guide fragments occupy content edge. Apple composes inline in populated list with a dedicated accessory strip. Mismatches: Reference default type size; no exact XXXL match. |
| `extras/composer-light-XXXL.png` | `../../reference/reminders-compose-light.png` | Separate composer clears native keyboard and exposes a dismiss control; setup-guide fragments occupy content edge. Apple composes inline in populated list with a dedicated accessory strip. Mismatches: Reference default type size; no exact XXXL match. |
| `extras/empty-dark-XXXL.png` | `../../reference/reminders-bottom-dark.png` | All Clear and dark guide are readable; paired Apple populated bottom is a palette/list proxy, not an empty-state match. Mismatches: No exact usable state reference; Reference default type size; no exact XXXL match; No empty reference in matching appearance. |
| `extras/empty-light-XXXL.png` | `../../reference/reminders-empty-light.png` | All Clear and exact setup instructions are readable, but much more visually prominent than quiet Apple empty canvas. Mismatches: Reference default type size; no exact XXXL match; Empty list state differs in app controls. |
| `extras/signin-dark-XXXL-default.png` | `../../reference/round2/reminders-compose-dark.png` | Unboxed auth hierarchy and system form/keyboard language are coherent; Apple reference is inline reminder composition, not authentication. Existing provider/email/secondary/legal actions fit without nested cards. Mismatches: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| `extras/signin-dark-XXXL-error.png` | `../../reference/round2/reminders-compose-dark.png` | Unboxed auth hierarchy and system form/keyboard language are coherent; Apple reference is inline reminder composition, not authentication. Existing full error text wraps; red expresses actual failure. Mismatches: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| `extras/signin-dark-XXXL-inbox.png` | `../../reference/round2/reminders-compose-dark.png` | Unboxed auth hierarchy and system form/keyboard language are coherent; Apple reference is inline reminder composition, not authentication. Inbox heading and existing address/recovery action fit. Mismatches: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| `extras/signin-dark-XXXL-password-keyboard.png` | `../../reference/round2/reminders-compose-dark.png` | Unboxed auth hierarchy and system form/keyboard language are coherent; Apple reference is inline reminder composition, not authentication. Focused password is above keyboard; floating Done crowds secondary action. Mismatches: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| `extras/signin-light-XXXL-default.png` | `../../reference/reminders-compose-light.png` | Unboxed auth hierarchy and system form/keyboard language are coherent; Apple reference is inline reminder composition, not authentication. Existing provider/email/secondary/legal actions fit without nested cards. Mismatches: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| `extras/signin-light-XXXL-error.png` | `../../reference/reminders-compose-light.png` | Unboxed auth hierarchy and system form/keyboard language are coherent; Apple reference is inline reminder composition, not authentication. Existing full error text wraps; red expresses actual failure. Mismatches: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| `extras/signin-light-XXXL-inbox.png` | `../../reference/reminders-compose-light.png` | Unboxed auth hierarchy and system form/keyboard language are coherent; Apple reference is inline reminder composition, not authentication. Inbox heading and existing address/recovery action fit. Mismatches: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| `extras/signin-light-XXXL-password-keyboard.png` | `../../reference/reminders-compose-light.png` | Unboxed auth hierarchy and system form/keyboard language are coherent; Apple reference is inline reminder composition, not authentication. Focused password is above keyboard; floating Done crowds secondary action. Mismatches: No Apple sign-in reference; compose compares native form/keyboard treatment only; Reference default type size; no exact XXXL match. |
| `full-dark-default-bottom-after-pull.png` | `../../reference/reminders-bottom-dark.png` | Final paragraph/line remains fully bright above hint/composer after pull and scroll; Apple final task is similarly crisp. Persistent app title/count remain visible; centered paragraph controls remain. Mismatches: Seeded app paragraphs differ from shorter reference reminder content. |
| `full-dark-default-top.png` | `../../reference/round2/reminders-top-dark.png` | Native plain-list text and separators are clear; app completion/grips are centered within long paragraphs versus Apple first-line circles. App inline title/count differs from Apple large title. Mismatches: Seeded app paragraphs differ from shorter reference reminder content. |
| `full-light-default-bottom-after-pull.png` | `../../reference/round2/reminders-bottom-light.png` | Final paragraph/line remains fully bright above hint/composer after pull and scroll; Apple final task is similarly crisp. Persistent app title/count remain visible; centered paragraph controls remain. Mismatches: Seeded app paragraphs differ from shorter reference reminder content. |
| `full-light-default-top.png` | `../../reference/reminders-top-light.png` | Native plain-list text and separators are clear; app completion/grips are centered within long paragraphs versus Apple first-line circles. App inline title/count differs from Apple large title. Mismatches: Seeded app paragraphs differ from shorter reference reminder content. |
| `long-text-dark-XXXL-bottom-after-pull.png` | `../../reference/reminders-bottom-dark.png` | Final paragraph/line remains fully bright above hint/composer after pull and scroll; Apple final task is similarly crisp. Persistent app title/count remain visible; centered paragraph controls remain. Mismatches: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| `long-text-dark-XXXL-top.png` | `../../reference/round2/reminders-top-dark.png` | Native plain-list text and separators are clear; app completion/grips are centered within long paragraphs versus Apple first-line circles. App inline title/count differs from Apple large title. Mismatches: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| `long-text-dark-default-top.png` | `../../reference/round2/reminders-top-dark.png` | Native plain-list text and separators are clear; app completion/grips are centered within long paragraphs versus Apple first-line circles. App inline title/count differs from Apple large title. Mismatches: Seeded app paragraphs differ from shorter reference reminder content. |
| `long-text-light-XXXL-bottom-after-pull.png` | `../../reference/round2/reminders-bottom-light.png` | Final paragraph/line remains fully bright above hint/composer after pull and scroll; Apple final task is similarly crisp. Persistent app title/count remain visible; centered paragraph controls remain. Mismatches: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| `long-text-light-XXXL-top.png` | `../../reference/reminders-top-light.png` | Native plain-list text and separators are clear; app completion/grips are centered within long paragraphs versus Apple first-line circles. App inline title/count differs from Apple large title. Mismatches: Seeded app paragraphs differ from shorter reference reminder content; Reference default type size; no exact XXXL match. |
| `long-text-light-default-top.png` | `../../reference/reminders-top-light.png` | Native plain-list text and separators are clear; app completion/grips are centered within long paragraphs versus Apple first-line circles. App inline title/count differs from Apple large title. Mismatches: Seeded app paragraphs differ from shorter reference reminder content. |
| `signin-dark-default-top.png` | `../../reference/round2/reminders-compose-dark.png` | Unboxed auth hierarchy and system form/keyboard language are coherent; Apple reference is inline reminder composition, not authentication. Existing provider/email/secondary/legal actions fit without nested cards. Mismatches: No Apple sign-in reference; compose compares native form/keyboard treatment only. |
| `signin-light-default-top.png` | `../../reference/reminders-compose-light.png` | Unboxed auth hierarchy and system form/keyboard language are coherent; Apple reference is inline reminder composition, not authentication. Existing provider/email/secondary/legal actions fit without nested cards. Mismatches: No Apple sign-in reference; compose compares native form/keyboard treatment only. |

## Verification and source limits

Reviewed packet: inventory.json, manifest.json, extras/manifest.json, activity/manifest.json, pairings.json, checks.json, validation/round2 README, provenance and structured test/build/warning summaries. Source navigation started with codedb_context. Scoped source reads covered ReminderListView/ReminderRow/composer/error/navigation, ReorderableReminderList, SignInView, AccountView, BoardSetupTip, BoardPersistenceSection, LMRChrome, ReminderAttributes/ReminderActivityPresentation, LockScreenLineBudget/ReminderActivityLinesView, ReminderLiveActivity and ReminderWidget. Reviewed the native board/account/sign-in/Activity tests and presentation/layout tests. No source-derived statement establishes unobserved runtime behavior.

Reported exact captured-build verification: `xcodebuild test-without-building -xctestrun /tmp/notepad-round2-dd/Build/Products/LazyMansReminders_iphonesimulator27.1-arm64.xctestrun -destination platform=iOS\ Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694 -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 180 -collect-test-diagnostics never -disableAutomaticPackageResolution -skipPackageUpdates -resultBundlePath /tmp/notepad-round2-combined.xcresult CODE_SIGNING_ALLOWED=NO`. Actual runtime in the result is iOS26.2; SDK-named xctestrun path is not runtime evidence. **249 unit +12 UI =261 passed,0 failed,0 skipped**. Exact argv is in test-command.json/checks.json.

The board tests now perform a real top pull, require settled refresh state, traverse to bottom, compare actual/intrinsic text height and inspect final-line raster ink. Account tests exercise large→medium→large, read-only scrolling, all lower actions, Done and reopen-large. Sign-in tests check field/control bounds and keyboard clearance, but do not assert action-versus-accessory separation. Native Activity footer test inspects actual SpringBoard footer frame. Unit-rendered Activity attachments remain separate and are not native substitutes.

Release: original overall exit0/artifact with unusual SwiftCompile exit0/no-output diagnostics is retained. Parent supplied a fresh clean-derived-data arm64-only exact-device confirmation in `../../validation/round2/release-arm64-confirmation.json`: exit0, BUILD SUCCEEDED, fresh binary, existing AuthManager weak-capture/unused-try warnings only. This resolves Release confirmation, not the sign-in invalid-frame warning. APNs entitlement, surface-notify and test-runner diagnostics remain documented in observed-warnings.json; no warning-free claim is made.

After owner fixes, use the existing runner with a fresh result path (recommendation, not executed by reviewer):

```bash
HILLCLIMB_UDID=78F5A64F-7B2E-4562-8EF9-10F3312CC694 HILLCLIMB_RESULT=/tmp/hillclimb-round2-sol-followup.xcresult scripts/hillclimb/check.sh
```

Keep all existing tests/assertions and add the finding-specific regression checks above. Record source SHA, exact command, result counts, runtime issues and native evidence. No further tests were run during grading.

## Evidence gaps

- Apple Notes unavailable/not installed: no Notes reference was used. All nine usable Reminders references were inspected; original four transition_rejected files were never opened or used. New round2 references close dark top/compose and light bottom/sheet gaps.
- Every app PNG is 1206x2622, logical402x874, regular iPhone17 Pro simulator on iOS26.2 build23C54. Same-device references are default type; XXXL comparisons have a size mismatch. Sign-in, Account-vs-Details, Activity-vs-list and dark-empty pairings have semantic limitations documented per state below.
- True locked-device Activity capture unavailable. Notification Center banners are native but are not a truly locked device. Expanded PNGs are unmodified native recording frames; collapsed stills omit the Island overlay and establish home/status state only. Hardware sensor-cutout geometry remains uncertified.
- No native Home Screen/accessory widget screenshots. Widget source was reviewed. SwiftUI unit-rendered Activity attachments are distinct from native captures and do not certify ActivityKit chrome or hardware geometry.
- Native Activity fixture bypasses production lines(from:) and injects eight raw lines. It validates surface layout, not nested payload-summary correctness or authenticated Activity lifecycle/network refresh.
- Physical haptics, animation continuity, VoiceOver traversal/focus, perceived responsiveness, frame times and arbitrary wallpapers/increased contrast were not observed by this reviewer. Stills and source cannot establish those behaviors; related scores are provisional.
- Native loading/progress, board/account failure, enabled authentication success and account destructive/network workflows were not captured. Auth and Account fixtures intentionally disable network controls; their dimming is not enabled-production contrast evidence.
- XXXL is extraExtraExtraLarge, not the largest accessibility size. Unit-rendered accessibility5 Activity checks do not substitute for native app coverage at accessibility sizes. Reduce Motion/Transparency settings lack native interaction evidence.
- 261 combined tests passed with zero failure/skip, but an invalid-frame runtime warning remains in sign-in keyboard matrix. No complete exported console is claimed. Existing compiler/APNs/surface/test-runner diagnostics remain recorded.
- Original Release command exited0 and produced an artifact despite unusual SwiftCompile exit0/no-output diagnostics. Fresh arm64-only clean-derived-data confirmation exited0 with BUILD SUCCEEDED and artifact, resolving build confirmation; existing AuthManager warnings remain.
- Reviewer performed read-only evidence/source inspection and no runtime tests/device operations. Captured source SHA is 8dbf6a8e07a5b88dd6748b77a5c8030740eb5309; inventory/provenance hashes and parent verification establish production-source equivalence after artifact-only commits. No claim that current git HEAD itself is the capture SHA.

## Inspected usable references

- `../../reference/reminders-bottom-dark.png`
- `../../reference/reminders-compose-light.png`
- `../../reference/reminders-empty-light.png`
- `../../reference/reminders-sheet-dark.png`
- `../../reference/reminders-top-light.png`
- `../../reference/round2/reminders-bottom-light.png`
- `../../reference/round2/reminders-compose-dark.png`
- `../../reference/round2/reminders-sheet-light.png`
- `../../reference/round2/reminders-top-dark.png`

Overall **8.11**; minimum **7.0**. Top3 fixes: keyboard-accessory separation, exact capacity-message wrapping, first-line row-control alignment.

Written by gpt-6.1-sol in Codex on behalf of Edmund
