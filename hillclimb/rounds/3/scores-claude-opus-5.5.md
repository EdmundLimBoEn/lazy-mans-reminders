# Round 3 UI/UX grades: claude-opus-5.5

Source `6959de17bb4d74fa1518914988645a3ea0313a68`. Actual catalog model id `claude-opus-5-5`, effort medium. Graded independently from 110 native captures (contact sheets for all states plus full-resolution originals of board bottom-after-pull default light and XXXL dark, Account top and XXXL large-lower, dark sign-in, and the XXXL light expanded Island) and SwiftUI/UIKit source. Paired against 17 Apple Reminders references. The two rejected transition frames and the unit-rendered Activity rasters are excluded.

**Overall: 8.25** (arithmetic mean of 30). Lowest category: 7.5. This does not meet the >=9 stop gate. Tests passing (276/276, 3x8 + 8 keyboard matrix) are credited for keyboard, targets and clearance, but they don't establish visual 9s.

| # | Category | Score | Rationale |
|---|---|---:|---|
| 1 | Visual hierarchy | 8.5 | Board puts reminder text first under a quiet inline title with live count; composer is clearly separated. Flat setup guide and flat sign-in sections read in order. Account sheet loses hierarchy in captures because nearly every row is dimmed by demo read-only mode while Delete Account... renders at full contrast, inverting emphasis. |
| 2 | Spacing/grid | 8.3 | Consistent 16-20pt margins, 44pt rows and 56pt separator inset aligned to text. Delete Account... trash glyph is larger and its title starts ~22px right of the AccountRow titles above (observed account-dark-XXXL-large-lower). Sign-in keyboard Done floats with a large gap above the keyboard. |
| 3 | Typography scale | 8.2 | Body for rows/composer, caption hint, headline section labels are Apple-like. 'Add a lasting widget' DisclosureGroup is footnote while sibling rows are body, a visible size break inside one inset group. Navigation subtitle '7 of 7' stays very small next to XXXL content. |
| 4 | Dynamic Type | 8.6 | XXXL board, composer capacity copy, account, guide and sign-in all reflow without truncation; Island caps at xxxLarge deliberately. Only default and XXXL were exercised; accessibility sizes (AX1-AX5) unobserved. |
| 5 | Light contrast | 8.4 | Primary text and separators read well in light. Board-full status and hint in secondary on secondarySystemBackground read faint but legible; demo-disabled Account/Sign-in rows are intentionally dim and excluded from scoring but make the evidence weaker. |
| 6 | Dark contrast | 8.0 | Dark board/account are clean. Measured: dark Sign in with Apple uses the .black style on a pure black background; the button region x70-330,y820-920 has max channel 0, so the button has no visible bounds while the Google button below has a filled RGB(38,38,41) container. |
| 7 | Iconography | 8.6 | SF Symbols throughout with consistent secondary weights; grip dots, light circle and arrow.up.right accessories are restrained. Delete trash glyph scale mismatches other row glyphs. |
| 8 | Safe area / Dynamic Island | 8.8 | Status bar, inline title, account button and composer stay clear of system areas in every capture; expanded Island text keeps clearance from corner curvature with added bottom margin. Compact/minimal intentionally empty. |
| 9 | Scroll/pull-down / last row | 8.4 | After pull, the final row and its separator sit fully above hint and composer at default and XXXL in both appearances. At the top edge, clipped glyph fragments of the previous row sit hard against the header (measured dark pixels at y344-356 in full-light-default-bottom-after-pull) with no soft scroll-edge, unlike Reminders. |
| 10 | List rows | 7.8 | Rows are clean and readable with leading circle, trailing grip and inset separators. Source: the entire row (circle and text) is one Button that completes the reminder immediately, with no undo; Reminders reserves completion for the circle and uses text tap for edit. Accidental completion risk on a post-it board is real. |
| 11 | Empty states | 8.8 | ContentUnavailableView 'All Clear' plus flat guide with dismiss; guide hides while composing and restores after. Native and calm. |
| 12 | Composer ergonomics | 8.6 | Pill field with hairline, 44pt hit targets, keyboard-dismiss glyph only when empty, intrinsic multi-line capacity copy. Board-full status still visually resembles a disabled text field. |
| 13 | Keyboard handling | 8.5 | Recheck images show keyboard, Done, and alternate action visible with interactive dismissal; 3x8 matrix + combined 8 passed with zero invalid-frame events. Custom Done bar rather than system keyboard toolbar leaves a tall empty band above keys. |
| 14 | Sheet presentation/detents | 8.5 | Medium/large detents, visible grabber, opaque grouped background, content scrolls under a native soft edge. At XXXL large-lower, ghosted footer text under the 'Account' title is busy but is the system edge effect. |
| 15 | Navigation clarity | 8.7 | Single board screen, one account entry, inline titles, Done confirmation placement. Clear. |
| 16 | Touch targets | 8.4 | 44pt circles, grips, dismiss, add, Done 48pt, legal links 44pt confirmed in source and tests. Conversely the whole multi-line row is a completion target (oversized destructive target). |
| 17 | Haptics | 7.5 | Source wires success/error sensoryFeedback and selection on drag start. No physical device, so no haptic was felt; unobserved. |
| 18 | Animation/transitions | 7.6 | Reduce-motion aware board animations and opacity transitions in source; only stills and four Island recordings were reviewed. No measured motion evidence. |
| 19 | Loading states | 8.5 | Centered large ProgressView with label; button spinners replace labels in place on sign-in. Simple and native. |
| 20 | Error states | 7.6 | Banner and full-screen error are structured well with dismiss and Try Again, and announcement de-duplication is in source. Observed copy shows raw 'The operation couldn't be completed. (NSURLErrorDomain error -1009.)' from localizedDescription, which is not user-grade language. |
| 21 | VoiceOver/labels | 8.2 | Thorough labels, hints, values, custom Move up/down actions, header traits. Spoken output and traversal order were never heard; source-derived only. |
| 22 | iOS HIG consistency | 8.1 | Largely native (UICollectionView list, insetGrouped settings, ContentUnavailableView, SignInWithAppleButton). Deviations: black Apple button on black background, row-tap completes, custom keyboard Done bar. |
| 23 | Lock Screen / Live Activity | 7.8 | Notification Center and expanded Island frames are clean glass/black with structured +N more counts. No true locked-device capture; at XXXL the Island shows only 2 lines with a mid-word ellipsis before '+8 more', low information density. |
| 24 | Sign-in/onboarding | 8.0 | Flat, honest layout with clear email/password toggle, inbox and error states. Dark Apple button lacks visible bounds; provider buttons are demo-disabled so enabled appearance is unobserved. |
| 25 | Settings/account | 8.1 | Clear grouping with status values and explanatory footer. Typography break on 'Add a lasting widget', destructive row misalignment, long dense footer paragraph; enabled row appearance unobserved because demo disables the whole list. |
| 26 | Performance feel | 7.6 | No frame-time or launch measurement. Tests and runtime logs show zero invalid frames, but feel is not measured. |
| 27 | Delight | 7.8 | Quiet and competent; little personality beyond the post-it hint and success haptic. Appropriate for minimal brief, not memorable. |
| 28 | Long text | 8.7 | Seven long paragraphs wrap cleanly at default and XXXL; no truncation in-app; capacity copy wraps intrinsically. |
| 29 | Reduced Motion / Transparency | 8.0 | Source honors reduceMotion, reduceTransparency and increased contrast (solid chrome, thicker hairlines). None of these settings were exercised on device. |
| 30 | Palette / minimalism | 9.0 | Neutral monochrome with system accent only for links; semantic red reserved for errors; no nested cards or decorative color. |

## Findings

### OPUS3-01 (medium): signin-dark-default-top.png; extras/signin-dark-*.png; recheck/signin-dark-*.png
- Evidence: Observed and measured: SignInAppleFill.fill returns .black in dark mode (ios/App/LMRChrome.swift:27-28). On systemBackground black, pixels x70-330,y820-920 around the Apple button have max channel 0; the control has no visible bounds while the Google button directly below has a RGB(38,38,41) fill. Apple's guidance is to avoid a black button on a black/dark background.
- Fix: Return .white (or .whiteOutline) for dark scheme; keep title, order and height. Add a unit assertion on SignInAppleFill.fill(.dark) and a pixel check that the button region contains non-background pixels.
- Confidence: high; basis: observed + source-derived
- Programmatic check: Sample button rect in dark capture; require >=1% pixels differing from background by >20 levels.

### OPUS3-02 (medium): full-*-top.png; long-text-*.png (rows)
- Evidence: Source: ReminderRow wraps circle and text in one Button(action: onComplete) (ios/App/ReminderListView.swift ReminderRow) and markDone runs immediately with no undo. Any tap on a multi-line paragraph completes it. Apple Reminders limits completion to the circle. Not exercised on device in this round.
- Fix: Make only the 44pt circle the completion Button; make text non-interactive (or reserved for future edit) and keep the leading swipe Complete. Alternatively add a brief undo toast. Keep VoiceOver row action 'Marks this reminder complete' via accessibilityAction.
- Confidence: high; basis: source-derived
- Programmatic check: UI test: tap text center of row 1 and assert row count unchanged; tap circle and assert completion.

### OPUS3-03 (medium): extras/board-error-*.png
- Evidence: Observed banner and full-screen error show 'The operation couldn't be completed. (NSURLErrorDomain error -1009.)'. Source passes error.localizedDescription straight through (presentError). Real devices may show the friendlier system string, but this capture shows the raw domain/code.
- Fix: Map URLError codes (notConnectedToInternet, timedOut, networkConnectionLost) to a short human message; fall back to localizedDescription. Product question: new copy needs owner approval since existing wording is preserved.
- Confidence: medium; basis: observed + source-derived
- Programmatic check: Unit test mapping URLError(.notConnectedToInternet) to a string without 'NSURLErrorDomain'.

### OPUS3-04 (low): full-light-default-bottom-after-pull.png; full-dark-default-bottom-after-pull.png
- Evidence: Measured: dark glyph pixels at y344-356 directly below the 'Your Board'/'7 of 7' header are clipped fragments of the previous row ('for tomorrow.'), drawn at full contrast with no soft top edge. The UICollectionView hosted via UIViewRepresentable keeps its top edge effect default but the clipped fragments remain crisp.
- Fix: Verify the nav bar is tracking the collection view as its content scroll view (e.g. .scrollEdgeEffectStyle(.soft, for: .top) or set topEdgeEffect explicitly); or snap the post-pull resting offset to a row boundary.
- Confidence: medium; basis: observed
- Programmatic check: Sample 20px band below header after pull; require max contrast < 3:1 vs background or no partial glyph rows.

### OPUS3-05 (low): account-*-top.png; extras/account-*-large-top.png
- Evidence: 'Add a lasting widget' DisclosureGroup is .font(.footnote) (BoardPersistenceSection.swift:41) while sibling rows are body; visibly smaller row in the same group.
- Fix: Apply .font(.footnote) only to the disclosed Text children, leaving the DisclosureGroup label at body.
- Confidence: high; basis: observed + source-derived
- Programmatic check: Snapshot assertion that row label font sizes in the section are equal.

### OPUS3-06 (low): extras/account-dark-XXXL-large-lower.png; extras/account-*-lower.png
- Evidence: Delete Account... uses Label with an unconstrained trash glyph while other rows use AccountRow with a 24pt icon frame and 14pt spacing; trash is larger and title starts ~22px further right. In captures it also renders at full contrast while every other row is demo-disabled.
- Fix: Render delete with AccountRow-like layout (24pt icon frame, 14pt spacing) keeping role .destructive, wording and icon. Confirm in a non-demo capture that it disables consistently.
- Confidence: high; basis: observed + source-derived
- Programmatic check: Geometry probe: title minX equal across Account rows.

### OPUS3-07 (low): activity/multiline-*-XXXL-expanded.png
- Evidence: At XXXL the expanded Island shows 2 lines with the second ending 'not...' then '+8 more'. Count conservation is correct but density is low and mid-word ellipsis reads rough.
- Fix: Allow one more line in the island budget at XXXL or cap island type at .xLarge so 3 lines fit; keep structured hidden count.
- Confidence: medium; basis: observed
- Programmatic check: LockScreenLineBudget unit test for island surface at xxxLarge >= 3 visible lines.

### OPUS3-08 (low): recheck/signin-*-keyboard.png
- Evidence: Custom Done bar in a bottom safeAreaInset leaves a tall empty band between content/links and the keyboard, and duplicates a system convention (keyboard toolbar).
- Fix: Use ToolbarItemGroup(placement: .keyboard) with Spacer + Done, preserving 48pt target and the tested alternate-action clearance.
- Confidence: medium; basis: observed
- Programmatic check: Existing keyboard matrix clearance assertions.

### OPUS3-09 (low): full-*-bottom-after-pull.png; long-text-*-XXXL-*.png
- Evidence: Board-full status text (body, secondary) inside the pill reads like a disabled text field placeholder rather than a status.
- Fix: Keep wording; render without the field pill (plain secondary text with the existing hint) or use .primary weight for the status with secondary hint.
- Confidence: medium; basis: observed
- Programmatic check: Contrast sample >= 4.5:1 for status text.

### OPUS3-10 (info): account-*.png; extras/account-*; extras/signin-*
- Evidence: Demo read-only mode disables the entire Account list and sign-in providers, so the enabled appearance of these rows was never captured.
- Fix: Add one non-interactive capture variant that renders enabled styling while blocking actions in handlers (as sign-in already does) rather than .disabled on the whole Group.
- Confidence: high; basis: source-derived
- Programmatic check: n/a (evidence gap)

## Evidence gaps

- No physical device: haptics, true Lock Screen, arbitrary wallpapers unobserved.
- Spoken VoiceOver output and traversal order never heard.
- Only default and XXXL sizes; AX1-AX5, Bold Text, Increase Contrast, Reduce Motion/Transparency unexercised on device.
- No measured motion/frame-time/launch performance.
- No Apple sign-in, Activity, loading/error or Notes counterparts; Account compared against Reminders Details semantically mismatched.
- Account and sign-in actions demo-disabled; enabled appearance unobserved.
- Row tap-to-complete not exercised; finding is source-derived.
- Unit-rendered Activity rasters excluded; Notification Center is not true locked-device evidence.
- Historical Release and backend results reused by hash identity, not rerun.

## Top fixes

1. Dark-mode Sign in with Apple: use the white style so the button has visible bounds (OPUS3-01).
2. Limit completion to the circle, or add undo (OPUS3-02).
3. Map URLError codes to human copy, pending owner approval (OPUS3-03).
4. Smaller polish items: soft top scroll edge, Account row font and alignment, Island XXXL density (OPUS3-04 to 07).

Reviewer only. No application, test, script or state files were changed.

Written by claude-opus-5.5 in Claude Code on behalf of Edmund
