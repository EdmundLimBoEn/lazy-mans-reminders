# Round 5 UI/UX review: claude-opus-5.5 (medium)

- Catalog model: `claude-opus-5-5`, effort medium, independent grader
- Source SHA: `c60288dae3173383442723e70f7874b8878d891d` (production = integrated K+L; M candidate rejected and not applied)
- Device: regular iPhone 17 Pro, iOS 26.2 (23C54), 1206×2622
- **Overall: 8.69** (arithmetic mean of 30, rounded to 2 decimals). **Minimum category: 7.8** (Haptics)
- Stop gate (overall ≥9 and every category ≥7): **not met**. These scores are not inflated to reach it.
- I did not read the round-5 Codex score reports or the aggregate `scores.json`.

## Coverage

- **Native states:** all 394 qualifying PNGs in `inventory.json`, viewed through all 37 contact sheets: core 2, extras 7, accessibility 4, signin-enabled 3, edge normal 3, edge solid 2, motion 1, keyboards 1, Activity 1, combined-keyboards 1, board 4, account-enabled 7, settings 1.
- **Full-resolution crops:** expanded Island XXXL dark; Sign In XXXL keyboard light (title band); Sign In XXXL password light (footer and home indicator); Account XXXL large-lower light (title band); long-text dark XXXL bottom-after-pull (final row, hint, status); board light default populated error (banner).
- **Apple references:** all 17 usable regular-17 Reminders references, through both reference contact sheets. Every image is compared to its paired reference in `pairings.json`.
- **Motion:** both video-inspection sheets, covering seven recordings at three distributed samples each. This shows sampled motion only.
- **Source read:** `ReminderListView`, `ReorderableReminderList` (UIKit list, top mask, grip, drag), `AccountView`, `SignInView` (layout, Done inset, legal footer), `LMRChrome`, `ReminderLiveActivity`, `LockScreenLineBudget`/`ReminderActivityLayout`/`ReminderActivityLinesView`, `BoardSetupTip`.
- **Validation read:** README, observations, pixel-geometry, native-top-falloff, manual-keyboard-geometry, activity-conservation, account-raster and no-launch-metric. Test counts are context only. They are never counted as visual 9s.

## Comparison with Apple references

- **Board top and bottom vs Reminders top/bottom (default and XXXL).** The board takes the same text-first approach with lighter chrome: an inline title with a count subtitle instead of the large blue title, and the same circle language and inset separators. The top edge now departs softly, like the reference. In the reference, rows above the title fade. Here, L's 24pt mask produces a band that rises from about 1.6:1 to about 20:1 within 72px, with no mask at a fresh top or during a pull. The final row clears the hint and composer in every bottom state. This is not Apple's blur, but it reads as native polish.
- **Empty board vs `reminders-empty-light`.** The reference is just a centred "No Reminders" label. Here, ContentUnavailableView plus a one-time tip gives a stronger empty state without nested cards. There is no dark empty reference.
- **Composer and keyboards vs Reminders compose (default and XXXL).** Reminders composes inline in the list. Here a bottom field is used, but the keyboard is native and the field stays clear of it. The pinned combined-setting captures show complete keyboards with Done and the alternate action visible.
- **Account vs the Reminders Details sheet.** The construction matches: insetGrouped list on a grouped background, grabber, an inline title with a trailing confirmation, and compact sections. Semantics differ, and there is no medium-detent reference. In the reference, the Details sheet's title band stays clean. In Account at medium and scrolled-large, ghost text shows beside the title (OPUS5-02).
- **Sign In, errors, loading, Activity and system settings.** There is no Apple counterpart. These are judged against general native form, list and typography treatment only.

## Findings (most severe first)

All findings are low severity. Every proposed fix keeps all strings, branding and the icon, and none shrinks type or drops content.

1. **OPUS5-01, low: XXXL expanded Island ends mid-word.**
   - Evidence (observed at full resolution): line 2 reads "Demo 2: Review the sample not…" above "+8 more". Counts and the footer/count/corner gates pass. The word-boundary candidate is correctly rejected because it removed a word that already fitted.
   - Fix: add `.allowsTightening(true)` to the Island line Text only. Do not reduce type size or drop words.
   - Check: render the island surface at xxxLarge and assert 2 visible and 8 hidden lines, with no ellipsis or an ellipsis only after a whole word. Then re-capture and run the 293-test suite.
   - Confidence: medium.
2. **OPUS5-02, low: soft-edge ghost text collides with sheet and Sign In titles.**
   - Evidence (observed): "Sign Out", "Privacy", "Support" or "Refresh Board Now" sit ghosted beside "Account" in the medium-recovered, medium-lower and XXXL large-lower captures. "Sign In" sits over the blurred intro paragraph in the XXXL keyboard captures. The Reminders references show the same native ghosting, so this is low severity.
   - Fix: on iOS 26, apply `.scrollEdgeEffectStyle(.hard, for: .top)` to the Account List and the Sign In ScrollView. Add no custom blur and no forced snapping.
   - Check: crop the title band and assert no non-title glyph pixel exceeds 1.5:1.
   - Confidence: medium.
3. **OPUS5-03, low: a dead send button stays visible at capacity.**
   - Evidence (observed and source): "Board full — combine lines instead" is status text, but a disabled tertiary arrow circle remains, because the add Button is always rendered and only disabled.
   - Fix: omit the add Button when `atCapacity`.
   - Check: at capacity, there is no hittable "Add reminder" in the AX tree, the status text keeps a 44pt minimum height and full width, and existing capacity and geometry assertions pass.
   - Confidence: high.
4. **OPUS5-04, low: the XXXL password form's resting footer sits under the home indicator.**
   - Evidence (observed at full resolution): the Privacy · Terms · Support baseline crosses the indicator. The footer is scroll content and is likely reachable, but no scrolled capture verifies that.
   - Fix: no change is needed if reachability is confirmed. Optionally add 16pt of bottom content margin.
   - Check: after scrolling to the bottom, footer maxY is at least 8pt above the bottom inset and all links are hittable.
   - Confidence: medium.
5. **OPUS5-05, low: the Account persistence paragraph is dense.**
   - Evidence (observed): the paragraph starting "iOS limits each Live Activity to eight hours…" runs 5 lines at default and 7–9 lines at XXXL in primary ink. It is the heaviest text block in the sheet.
   - Fix: split the existing string at its sentence boundaries into two Text views with 6pt spacing. The words stay identical.
   - Check: the concatenated text equals the current string, both parts keep at least 7:1 contrast, and the guidance captures pass.
   - Confidence: medium.

The raw network error wording is a closed product decision: Edmund answered "Keep existing wording" on 2026-11-05. It is not a finding. Only its presentation is scored, under Error states.

### Status of round-4 findings

- **OPUS4-01:** resolved. The alternate action is visible after a pan, with at least 116pt clearance and Done at 48pt.
- **OPUS4-02:** resolved. The clipped crisp fragments are replaced by the departing-content mask.
- **OPUS4-03:** closed by product decision.
- **OPUS4-04:** resolved. Each row has one completion stop plus a separate grip.
- **OPUS4-05:** resolved. Enabled-style legal links render in primary ink.
- **OPUS4-06:** still open, carried forward as OPUS5-01.

## Scores

| # | Category | Score | Basis |
|---|---|---|---|
| 1 | Visual hierarchy | 8.9 | observed |
| 2 | Spacing/grid | 8.8 | observed |
| 3 | Typography scale | 8.8 | observed + source |
| 4 | Dynamic Type | 8.8 | observed to XXXL; AX sizes unobserved |
| 5 | Light contrast | 8.9 | observed + packet rasters |
| 6 | Dark contrast | 8.9 | observed |
| 7 | Iconography | 8.8 | observed |
| 8 | Safe area / Dynamic Island | 8.9 | observed + geometry |
| 9 | Scroll/pull-down / last row | 8.9 | observed + geometry (16 states) |
| 10 | List rows | 8.9 | observed + AX snapshots |
| 11 | Empty states | 8.9 | observed |
| 12 | Composer ergonomics | 8.7 | observed (OPUS5-03) |
| 13 | Keyboard handling | 8.8 | observed (pinned captures); protected-image partial |
| 14 | Sheet presentation/detents | 8.7 | observed (OPUS5-02) |
| 15 | Navigation clarity | 8.9 | observed |
| 16 | Touch targets | 9.1 | source + AX geometry + edge taps |
| 17 | Haptics | 7.8 | source only, provisional |
| 18 | Animation/transitions | 8.2 | sampled recordings + source |
| 19 | Loading states | 8.7 | observed |
| 20 | Error states | 8.7 | observed; wording closed |
| 21 | VoiceOver/labels | 8.6 | source + AX snapshots; spoken unobserved |
| 22 | iOS HIG consistency | 8.8 | observed + source |
| 23 | Lock Screen / Live Activity | 8.1 | Notification Center + Island observed (OPUS5-01) |
| 24 | Sign-in/onboarding | 8.8 | observed |
| 25 | Settings/account | 8.7 | observed (OPUS5-05) |
| 26 | Performance feel | 7.9 | unmeasured, provisional |
| 27 | Delight | 8.1 | observed + source |
| 28 | Long text | 8.8 | observed |
| 29 | Reduced Motion / Transparency | 8.7 | actual Settings observed; motion source-derived |
| 30 | Palette / minimalism | 9.1 | observed |

The total is 260.7, and 260.7 / 30 = 8.69. The detailed rationale for each category is in the JSON.

## Why the overall is not 9

- The three categories graded only from source or sampled evidence (Haptics, Performance feel, Animation) cannot honestly reach 9 without physical-device observation.
- Lock Screen / Live Activity still has the XXXL mid-word tail, and true locking is unobserved.
- The visual categories sit around 8.7–9.1. The remaining gaps are small native-polish issues (OPUS5-02 to OPUS5-05), not structural problems.

## Evidence limits

- **Not observed:** physical haptics, spoken VoiceOver, true Lock Screen and wallpapers, AX1–AX5, live auth/AutoFill, and launch or frame performance.
- **Partial or excluded evidence:** the eight XCTest password images are partial; the pinned manual captures are the complete keyboard evidence. Unit renders and rejected captures are excluded.
- **No reference:** there is no Notes reference, and no exact Apple counterpart for sign-in, Account, Activity, error, loading, medium-detent or settings states.
- **Not performed:** no device actions, builds, live API calls or app edits.

Written by claude-opus-5.5 in Claude Code on behalf of Edmund
