# Round 4 UI/UX grades: claude-opus-5.5

Source `b5d9bb3df1b20d765ae5efff438190f396827456`. Catalog model id `claude-opus-5-5`, effort medium, one pass with no subagents. Graded independently from all 288 native captures (27 category contact sheets plus full-resolution crops of the board top edge after pull, the populated error banner, the sign-in legal footer, the combined-settings sign-in keyboard and the XXXL Island), sampled frames from the composer and combined-settings recordings, and the SwiftUI/UIKit source diff since round 3. Paired against 17 hash-verified Apple Reminders references. Unit-rendered Activity rasters, rejected images and the AutoFill segment are excluded. Codex round 4 scores were not read.

**Overall: 8.51** (arithmetic mean of 30, sum 255.4). Lowest category: 7.6 (Haptics). The ≥9 stop gate is **not met**. The 285/285 tests, 8-case keyboard matrix, zero invalid frames and pixel checks are credited where they apply, but they don't establish visual 9s.

| # | Category | Score | Rationale |
|---|---|---:|---|
| 1 | Visual hierarchy | 8.8 | Board leads with reminder text under a quiet inline title and live count. Board-full status is now primary unboxed text above a readable hint, so it no longer reads as a disabled field. The error banner has a headline title, raw detail and Try Again in a clear order. Enabled-style Account fixtures show normal row emphasis, and Delete Account… is the only red row. Residual: the full-screen error leads with a raw diagnostic under its title. |
| 2 | Spacing/grid | 8.7 | Margins of 16–20pt, 44pt rows and inset separators are consistent. Delete Account… now uses AccountRow (24pt icon, 14pt gap), and the validation's title-geometry alignment check passed. The sign-in Done bar lost its extra vertical padding and now sits close above the keyboard. Minor: Account section headers such as 'Keep Your Board Visible' sit tight under the preceding footer paragraph (system grouped spacing). |
| 3 | Typography scale | 8.7 | Body for rows, composer and Account rows; footnote for helpers; headline for banner and section titles. The 'Add a lasting widget' label is back at body, with only the disclosed children at footnote (observed, both detents). The navigation subtitle '7 of 7' stays very small next to XXXL body text. |
| 4 | Dynamic Type | 8.7 | XXXL board, composer, banner, Account (medium and large detents, expanded guidance, errors) and sign-in all reflow without truncation in captures. The Island caps text by design. AX1–AX5 were not captured, and XXXL is extraExtraExtraLarge, not an accessibility size. |
| 5 | Light contrast | 8.6 | Account helper and footer ink measured ≥13.9:1 (validation, 54 samples). The board capacity hint and guide text were lifted to primary at 75%. Measured on signin-light-default-top: the demo-disabled legal footer is (197,197,199) on white, 1.72:1. Its enabled appearance was never captured, even in the enabled-style fixture (see OPUS4-05). |
| 6 | Dark contrast | 8.8 | The dark Sign in with Apple button is now a white outlined fill with clear bounds on black (observed, resolving OPUS3-01). Dark board, banner and Account are clean. The demo-disabled legal footer measures (70,70,73) on black, 2.23:1, and its enabled appearance is unobserved. |
| 7 | Iconography | 8.8 | SF Symbols throughout. The banner warning glyph is primary rather than red, the destructive trash glyph is red and size-matched in a 24pt frame, and arrow.up.right accessories are restrained. Consistent weights. |
| 8 | Safe area / Dynamic Island | 8.8 | Status bar, inline title, account button, banner and composer stay clear of system areas in every capture. The expanded Island keeps text inside its corner curvature. Compact and minimal presentations are intentionally empty. |
| 9 | Scroll/pull-down / last row | 8.4 | All four true-bottom geometries pass, with the final row fully above hint and composer. Unresolved: measured on all four default bottom-after-pull captures, 14 pixel rows (y348–361) of clipped previous-row glyphs exceed 3:1 directly under the header. topEdgeEffect.style = .soft produced no visible softening. The same crisp fragment shows under the bottom edge of the populated error banner. |
| 10 | List rows | 8.8 | Completion is now limited to the 44pt circle. completion-text-tap captures keep '7 of 7', and completion-after shows '6 of 7' in all four style/size variants (observed). The text is static, and reorder grips remain. There is no undo, which matches Reminders. |
| 11 | Empty states | 8.9 | ContentUnavailableView 'All Clear' with a higher-contrast description and a flat dismissible guide. The guide hides while composing and returns after dismissal, observed in stills and in the composer recording. |
| 12 | Composer ergonomics | 8.8 | The keyboard-dismiss glyph now shows with a non-empty draft, and the draft is retained after dismiss and refocus (observed in the nonempty-* stills and the composer recording). The capacity state is unboxed primary text. Send and dismiss targets are 44pt. |
| 13 | Keyboard handling | 8.5 | Eight normal-settings post-scroll cases pass: Done is 48pt with ≥116pt alternate-action clearance and zero invalid frames. Replacing the native keyboard toolbar removed the localizedInputAccessoryBar invalid frames. With all three accessibility settings on at XXXL, the settled still hides 'Use an Existing Password' below the viewport. The recording at about 7.7s, before the AutoFill menu, shows it visible above Done. Reachability looks plausible, but the combined-settings clearance matrix is incomplete. |
| 14 | Sheet presentation/detents | 8.7 | Medium and large detents captured in enabled style, including error, refresh-error, reappear and recover sequences. Grabber, opaque grouped background and a native soft edge are present. At large-lower, ghosted footer text under the 'Account' title is busy but is the system edge effect. |
| 15 | Navigation clarity | 8.8 | Single board, one Account entry with Done, and an inline sign-in title after scrolling. Recovery paths (banner Try Again and dismiss, Account local retry) are discoverable. |
| 16 | Touch targets | 8.8 | Completion circle 44pt, grips 44pt, banner dismiss 44pt, Try Again minimum 44pt, Done 48pt, legal links 44pt. The oversized whole-row completion target is gone. |
| 17 | Haptics | 7.6 | Source wires success and error sensoryFeedback, a hapticTick on local completion, and selection on drag. Nothing was felt on a physical device, so this is unobserved. |
| 18 | Animation/transitions | 8.0 | Proportionate review of the composer, Account scroll, Activity and combined-settings recordings. Guide opacity transitions, keyboard rise and Island expansion look calm with no visible jumps. These are simulator recordings, and the encoded fps includes idle frames, so they don't certify frame pacing. |
| 19 | Loading states | 8.6 | Centered ProgressView with a label at default and XXXL in both styles. Sign-in buttons swap label for spinner in place. Banner Try Again disables while loading (source). |
| 20 | Error states | 8.0 | The banner now has a title, the full raw detail and a Try Again that recovers locally (retry-recovered observed). Account error and refresh-error rows appear, recover and reappear, and announcement dedup is in source. The visible copy is still the raw 'The operation couldn’t be completed. (NSURLErrorDomain error -1009.)' in both banner and full screen. Changing it is an open product copy question. |
| 21 | VoiceOver/labels | 8.2 | Labels, hints, values, a named Complete action and Reorder elements are present (AX snapshots). Spoken output and traversal were never heard. Source-derived risk: the row now exposes the circle Button labelled with the full reminder text and a separate visible Text with the same text inside a .contain element (OPUS4-04). |
| 22 | iOS HIG consistency | 8.6 | Native list, insetGrouped settings, ContentUnavailableView, and a white-outline Apple button on both appearances. Completion is limited to the circle as in Reminders. The custom Done bar is a justified deviation, since the native keyboard toolbar produced invalid frames. The remaining deviation is the crisp top-edge fragment the system edge effect should hide. |
| 23 | Lock Screen / Live Activity | 7.8 | Native multiline Activity accounts for all 10 lines (5+5/4+6 Notification Center, 3+7/2+8 Island). Notification Center glass is clean. The XXXL Island still shows only 2 lines, the second ending mid-word ('not…'), before '+8 more' (unchanged from OPUS3-07). No truly locked physical device was available. |
| 24 | Sign-in/onboarding | 8.6 | The enabled-style fixture shows Apple (white outline) and Google (tinted fill) as they will look, with primary helper ink and inbox, error, loading and password states. The legal footer still renders disabled in the enabled fixture. The combined-settings keyboard viewport concern is noted under Keyboard handling. Live authentication was not exercised. |
| 25 | Settings/account | 8.7 | Enabled rows read normally. The disclosure label is body size, footers measure ≥13.9:1, and the delete row aligns. The error and refresh-error states recover and reappear in place. The footer paragraph under Keep Your Board Visible is long and dense. Only local and synthetic actions were exercised. |
| 26 | Performance feel | 7.7 | Zero runtime warnings and zero scoped invalid-frame events, with 9359 other log events retained. Recordings look smooth in the simulator. There is no launch or frame-time metric, and physical feel is unmeasured. |
| 27 | Delight | 7.9 | Quiet, competent and on-brief. The post-it hint and success haptic are the personality. Not memorable, which suits the minimal taste brief. |
| 28 | Long text | 8.7 | Seven long paragraphs wrap cleanly at default and XXXL, the capacity copy wraps, and Account footers wrap. No in-app truncation. The Island mid-word ellipsis is scored under Lock Screen / Live Activity. |
| 29 | Reduced Motion / Transparency | 8.4 | Real OS Settings toggles (Reduce Motion, Reduce Transparency, Increase Contrast) were enabled, confirmed and restored. The board, Account and sign-in render solid chrome with no glass blur and a darker tint (observed). Only selected states were captured, with no side-by-side motion comparison. |
| 30 | Palette / minimalism | 9.0 | Neutral monochrome plus the system accent for links and actions. Red appears only for semantic error and destructive use, and the banner glyph moved from red to primary. No nested cards and no decorative red or orange. |

## Findings

### OPUS4-01 (medium): accessibility/signin-light-XXXL-all-three-settled.png; accessibility/selected-states-all-three-enabled.mp4 (~7.7s, before AutoFill at ~9.63s)
- Evidence: Observed: with Reduce Motion, Reduce Transparency and Increase Contrast on at XXXL, the settled still shows Done (48pt) above the keyboard, but 'Use an Existing Password' is below the visible form and absent from the AX snapshot. The recording frame at about 7.7s, before the AutoFill menu, shows it visible above Done, so it is likely reachable, but the post-pan resting position does not keep it in view. Source: SignInView only scrolls to signin.alternateTarget on keyboardDidShow. This is not diagnosed as unreachable, and the recording is not a clean keyboard demo.
- Fix: Reproduce the lower-form scroll position under the three settings. If confirmed, also scroll to signin.alternateTarget on keyboardDidChangeFrame and on focus change (not only keyboardDidShow), and keep the existing 48pt Done and 116pt clearance.
- Confidence: medium; basis: observed
- Programmatic check: Add the combined-settings variant to the keyboard matrix: after focus and a pan, assert signin.alternateTarget is hittable and its maxY ≤ Done.minY − 8pt.

### OPUS4-02 (low): full-light-default-bottom-after-pull.png; full-dark-default-bottom-after-pull.png; board/*-default-true-bottom-after-pull.png; board/*-populated-error-bottom.png
- Evidence: Measured: in all four default bottom-after-pull captures, 14 pixel rows (y348–361) under the '7 of 7' header have glyph pixels above 3:1 against the background: crisp clipped fragments of 'for tomorrow.'. ReorderableReminderList sets topEdgeEffect.style = .soft, but nothing visibly softens. A matching crisp fragment shows under the populated error banner. Reminders references fade rows under the top chrome.
- Fix: Bind the UIKit collection view as the hosting controller's content scroll view for the top edge (setContentScrollView(list, for: .top)) so the nav bar edge effect tracks it. Alternatively, snap the post-pull resting offset to a row boundary. Keep the bottom-row clearance unchanged.
- Confidence: medium; basis: observed + source-derived
- Programmatic check: Extend pixel-geometry-results: in the 20px band below the header after pull, require no pixel row with contrast >3:1 (or require top-edge alpha falloff).

### OPUS4-03 (medium): extras/board-error-*.png; board/*-populated-error*.png
- Evidence: Observed: the banner and full-screen error show 'The operation couldn’t be completed. (NSURLErrorDomain error -1009.)'. The new title and Try Again help, but the body is a raw diagnostic. Unchanged since OPUS3-03 by design, because wording is preserved.
- Fix: Product question, needs owner-approved copy: map URLError codes (.notConnectedToInternet, .timedOut, .networkConnectionLost) to a short human line under the existing 'Couldn’t Load Board' title, and keep the raw diagnostic available (for example selectable footnote or disclosure). Until approved, keep the current layout and make no copy change.
- Confidence: high; basis: observed + source-derived
- Programmatic check: Unit test: mapping URLError(.notConnectedToInternet) yields approved copy without 'NSURLErrorDomain', with raw text retained in the diagnostic field.

### OPUS4-04 (low): board/*-top.png (AX .txt); ios/App/ReminderListView.swift ReminderRow
- Evidence: Source-derived: ReminderRow is .accessibilityElement(children: .contain) holding a circle Button labelled with reminder.text and a visible Text(reminder.text) that is not hidden from accessibility. The AX snapshot shows the cell and the button both carrying the full paragraph. VoiceOver may read each long paragraph twice (button, then static text). Not heard.
- Fix: Mark the visible Text .accessibilityHidden(true) (the button already carries label, value, hint and the Complete action), or combine the row into one element with the Complete and Reorder actions.
- Confidence: medium; basis: source-derived
- Programmatic check: UI test: within the first cell, assert exactly one accessibility element whose label equals the reminder text.

### OPUS4-05 (low): signin-enabled/*.png; signin-*-default-top.png
- Evidence: Measured: the legal footer is (197,197,199) on white, 1.72:1, and (70,70,73) on black, 2.23:1. Source: legalFooter uses .disabled(blocksExternalActions), not disablesDemoControls, so even the enabled-style fixture renders the links disabled. Their enabled appearance is never captured.
- Fix: Use disablesDemoControls for legalFooter. Hit testing is already blocked by .allowsHitTesting(!appearanceFixture), and openURL can be discarded as in AccountView. Then recapture to confirm tint contrast.
- Confidence: high; basis: observed + source-derived
- Programmatic check: Pixel check on the enabled signin capture: legal link ink ≥4.5:1 against the background.

### OPUS4-06 (low): activity/multiline-*-XXXL-expanded.png
- Evidence: Observed: the XXXL expanded Island shows 'Demo 1…' and 'Demo 2: Review the sample not…' then '+8 more'. The count adds up, but density is low and the mid-word ellipsis reads rough. Unchanged from OPUS3-07.
- Fix: Allow one more line in the island budget at xxxLarge, or cap Island type at .xLarge so 3 lines fit. Keep the structured hidden count.
- Confidence: medium; basis: observed
- Programmatic check: LockScreenLineBudget unit test: island surface at xxxLarge yields ≥3 visible lines.

## Round 3 Opus findings disposition

| ID | Disposition | Note |
|---|---|---|
| OPUS3-01 | Resolved | Dark Apple button is now a white outlined fill with visible bounds (signin-dark-*-top.png, signin-enabled). |
| OPUS3-02 | Resolved | Completion is limited to the circle. Text tap leaves the count at 7 of 7, and a circle tap gives 6 of 7 (board/*-completion-*). |
| OPUS3-03 | Open (product question) | Title and Try Again were added, but the raw copy is preserved pending owner wording. Carried as OPUS4-03. |
| OPUS3-04 | Not resolved | A soft top edge was set, but crisp fragments remain (measured). Carried as OPUS4-02. |
| OPUS3-05 | Resolved | Disclosure label is body size, and only the disclosed helpers are footnote. |
| OPUS3-06 | Resolved | Delete uses AccountRow with a destructive red icon and title. Alignment check passed. |
| OPUS3-07 | Not resolved | XXXL Island is still 2+8 with a mid-word ellipsis. Carried as OPUS4-06. |
| OPUS3-08 | Closed, justified | The native keyboard toolbar caused localizedInputAccessoryBar invalid frames. The custom bar stays, with padding reduced and the 48pt target kept. |
| OPUS3-09 | Resolved | Board-full status is unboxed primary text, and the hint contrast passed. |
| OPUS3-10 | Mostly resolved | Enabled-style sign-in and Account fixtures were added. The legal footer was missed (OPUS4-05). |

## Evidence gaps

- No physical device: haptics, physical performance feel, true locked-device Lock Screen and arbitrary wallpapers unobserved; Notification Center banner is not a physical Lock Screen.
- Spoken VoiceOver output and traversal order never heard; OPUS4-04 is source-derived.
- Only default and XXXL (extraExtraExtraLarge); AX1–AX5 native layouts not captured.
- Accessibility settings exercised only for selected combined-on states; full AX keyboard clearance matrix pending (OPUS4-01).
- No launch or frame-time metrics; encoded fps of the recordings includes idle frames and does not certify frame pacing.
- No Apple Notes, authentication, Activity or loading/error counterparts among references; Account is paired with Reminders Details (semantic and detent differences).
- Sign-in and Account enabled-style fixtures are inert/local; no live auth, account mutation, provider, legal link or store write was exercised.
- Legal footer enabled appearance never captured (OPUS4-05).
- Unit-rendered Activity rasters excluded; compact/minimal Activity intentionally empty.
- The combined-settings recording contains an AutoFill menu segment (~9.63s); only the pre-menu frame (~7.7s) is used, as partial evidence of reachability.

## Top fixes

1. Reproduce and, if confirmed, harden the alternate-action scroll under the combined accessibility settings, and add that case to the matrix (OPUS4-01).
2. Bind the collection view to the top edge effect, or snap the resting offset, so no crisp fragments remain under the header or banner (OPUS4-02).
3. Product question: approve human copy for URLError cases and keep the raw diagnostic secondary (OPUS4-03).
4. Small items: hide the duplicate row Text from VoiceOver (OPUS4-04), enable the legal footer in the appearance fixture (OPUS4-05), and fit 3 Island lines at XXXL (OPUS4-06).

## Screenshot manifest

All 288 PNGs in inventory.json (paths relative to hillclimb/rounds/4) were inspected via contact sheets. The full list is in scores-claude-opus-5.5.json `screenshots`. References: `../../reference/reminders-bottom-dark.png`, `../../reference/reminders-compose-light.png`, `../../reference/reminders-empty-light.png`, `../../reference/reminders-sheet-dark.png`, `../../reference/reminders-top-light.png`, `../../reference/round2/reminders-bottom-light.png`, `../../reference/round2/reminders-compose-dark.png`, `../../reference/round2/reminders-sheet-light.png`, `../../reference/round2/reminders-top-dark.png`, `../../reference/round3/reminders-bottom-dark-XXXL.png`, `../../reference/round3/reminders-bottom-light-XXXL.png`, `../../reference/round3/reminders-compose-dark-XXXL.png`, `../../reference/round3/reminders-compose-light-XXXL.png`, `../../reference/round3/reminders-sheet-dark-XXXL.png`, `../../reference/round3/reminders-sheet-light-XXXL.png`, `../../reference/round3/reminders-top-dark-XXXL.png`, `../../reference/round3/reminders-top-light-XXXL.png`.

Reviewer only. No application, test, script or state files were changed.

Written by claude-opus-5.5 in Claude Code on behalf of Edmund
