# Round 3 independent review — gpt-6-astra

Overall: **8.76/10**. Minimum category: **7.8**. This does not meet the overall 9 stop gate. Scores are independent of the gate and other graders.

Production source: `6959de17bb4d74fa1518914988645a3ea0313a68`.

Independent review of all 110 native states through contact sheets, meaningful original-resolution samples and production SwiftUI/Activity source. Every recheck keyboard original and all four bottom-after-pull originals inspected individually. All 17 paired references inspected individually or in the 8-image XXXL sheet. All 110 native-image and 53 production-input hashes independently verified with zero mismatches. No application/test edits, device operations, builds, test executions or git mutations by reviewer. Unit rasters and rejected transition images excluded.

## Evidence and comparison

Current combined result: **276/276 passed (260 unit +16 UI), zero skipped**. Three additional fresh-process matrices covered 24 keyboard cases, plus 8 in the combined suite. Every recheck original shows a scrolled form, real keyboard and separated Done/alternate action. Recorded runtime warnings and scoped invalid-frame counts are zero; unrelated diagnostics remain. I read preserved results, not newly executed tests. Historical 275/1 remains a failed historical run. Fresh Debug/Python 23 are recorded; successful Release/Deno 52+4 are explicitly reused on production identity.

All 110 native images and 53 production-input hashes matched the inventory independently. Contact sheets are inspection aids only; twelve unit-rendered rasters and rejected transition images did not establish native geometry.

Board top/bottom states were compared with paired Apple Reminders top/bottom references, including eight new XXXL references. First-line circles now follow useful reference behavior; denser paragraphs partly reflect longer fixture copy. All four final-row originals retain complete final ink above the composer. Capacity wording wraps without ellipsis. The compact heading/composer need not copy Apple’s large colored heading/floating plus.

Composer and all sign-in variants were compared with paired native compose references for type, inputs, keyboard treatment and navigation material only; Apple supplies no auth equivalent. All eight post-scroll recheck originals were inspected individually: Done remains distinct and above the keyboard. Navigation blur over scrolled content also occurs in Apple references and is not graded as an overlap failure.

All guide before/focused/restored states were compared with the closest available empty/list reference, respecting disclosed type/semantic gaps. The full flat guide yields during typing and restores afterward. Loading/error/recovery have no Apple semantic counterpart; comparison concerns native hierarchy and typography only.

All Account medium/large top/lower combinations were reviewed against Apple Details. Native grouped materials and text reflow are coherent; footer/version reach the bottom. Disabled demo actions cannot establish enabled-production contrast. The long persistence explanation is information-dense but reachable, not clipped.

Native Activity banner totals are 5+5/default and 4+6/XXXL; expanded Island totals 3+7/default and 2+8/XXXL. Overflow conserves the original ten lines. The second XXXL Island excerpt tail-truncates under the single-line contract, with the overflow footer clear. Paired list references establish type comparison only. Compact/minimal content is intentionally empty. Notification Center is not certified true physical Lock Screen.

## Prioritized findings

### R3A1 — P2: Board composer with nonempty unsent draft, especially an empty board

The captured empty draft correctly has Done. The source condition composerFocused && draft.text.isEmpty removes it as soon as text is entered. The empty-board ScrollView has no explicit interactive keyboard-dismiss setting and no other dismiss action in its content. The composer UI test never enters text. This is an affordance gap inferred from source, not an observed stuck-keyboard failure.

Evidence: [composer-dark-default-top.png](composer-dark-default-top.png), [extras/guide-light-XXXL-focused.png](extras/guide-light-XXXL-focused.png). Source: ReminderListView.swift:134,289; HillclimbUITests.swift:103.

Fix: Keep the existing keyboard-dismiss icon and Done accessibility label available whenever focused, including a nonempty draft. Preserve draft and Add action with the same 44pt target and no new wording/decorative styling. Consider interactive dismissal for the empty-board ScrollView too.

Confidence: high for conditional removal; medium for practical impact. Basis: source-derived; screenshots establish empty-draft baseline only.

Regression check: Add a native UI case entering one and four lines on an empty board, tapping Done at its edge, asserting keyboard absence and exact draft retention, then refocusing. Repeat light/dark/default/XXXL; run the complete existing iOS suite. Proposed check not run by reviewer.

### R3A2 — P2: Light small capacity guidance and sign-in helper text

Original PNG pixel inspection found solid text RGB (138,138,142) on white in both informational labels, approximately 3.44:1. These instructions are not disabled controls. Faintness is visible at original resolution. Apple also uses quiet secondary labels; native styling does not remove this readability weakness.

Evidence: [full-light-default-bottom-after-pull.png](full-light-default-bottom-after-pull.png), [recheck/signin-light-default-keyboard.png](recheck/signin-light-default-keyboard.png). Source: ReminderListView.swift:236-238; SignInView.swift:254-256.

Fix: Use stronger adaptive neutral foreground for essential small guidance, preserving every word, type scale and spacing. Target 4.5:1 for normal-size informational text in light mode, keep dark-mode readability and avoid bright accent styling.

Confidence: high. Basis: observed + read-only programmatic pixel measurement + source-derived style.

Regression check: Reviewer ran Pillow Counter on original 1206x2622 PNGs: capacity box (40,2200,1140,2295), helper box (50,590,1100,645). Dominant solid ink #8a8a8e on white gives sRGB contrast 3.438876789. Add a native capture/pixel regression in standard/increased contrast excluding antialiased edges and genuinely disabled controls; run existing iOS suite after changes.

### R3A3 — P2: Account errors after sign-out or delete-account

Board/sign-in explicitly announce new errors. Account still inserts a top error section with updatesFrequently and a haptic, without a deliberate announcement/focus policy. Failure from a lower action can leave the error outside the visible viewport without established spoken feedback. No Account-failure capture or spoken run proves that outcome; this is the remaining Account portion of round2 R2A6.

Evidence: [extras/account-light-XXXL-large-lower.png](extras/account-light-XXXL-large-lower.png), [extras/account-dark-default-medium-lower.png](extras/account-dark-default-medium-lower.png). Source: AccountView.swift:20-26,129,270.

Fix: Apply the same deduplicated announcement approach to Account errors using the exact existing message, retaining focus on the initiating action. Make the error discoverable after confirmation dismissal without an unexpected scroll jump. Preserve copy.

Confidence: medium-high for missing policy; medium for impact. Basis: source-derived accessibility risk; not observed VoiceOver failure.

Regression check: Add once-per-presentation policy coverage and a controlled native failure from lower Account. With VoiceOver on, verify one spoken error, logical focus and reachable retry/cancel path at both detents. Run full existing iOS suite. Speech verification was not performed.

### R3A4 — P3: Empty/populated board network failure

Observed failure makes The operation couldn’t be completed. (NSURLErrorDomain error -1009.) the primary explanation. Empty state has Try Again; populated banner offers only dismiss. Layout/recovery are sound but a raw diagnostic is weak recovery guidance. Not every production error is claimed to produce this exact string.

Evidence: [extras/board-error-empty-light-default.png](extras/board-error-empty-light-default.png), [extras/board-error-populated-dark-XXXL.png](extras/board-error-populated-dark-XXXL.png), [extras/board-error-populated-dark-XXXL-recovered.png](extras/board-error-populated-dark-XXXL-recovered.png). Source: ReminderListView.swift:468,498,520; BoardErrorBanner.

Fix: Preserve wording by retaining the full diagnostic in accessible secondary detail, use existing Couldn’t Load Board for hierarchy, and expose existing Try Again directly for populated recovery. If frozen-copy constraints prohibit placement changes, prioritize retry and defer text changes for explicit product direction.

Confidence: high for fixture presentation; medium for real-network prevalence. Basis: observed + source-derived direct localizedDescription forwarding.

Regression check: Add a native populated-cache failure that invokes Try Again, verifies one refresh, preserves cached text, and restores the success state. Assert 44pt target, no XXXL final-row occlusion and no duplicate announcement; run full existing iOS suite. Proposed test not run here.

## Category scores

| Category | Score | Rationale |
|---|---:|---|
| Visual hierarchy | 9.0 | Reminder text leads the board, with a compact title/count and quiet composer. The flat setup guide yields during editing. Account has native section hierarchy; technical error detail is still too prominent. |
| Spacing/grid | 8.9 | Consistent margins, first-line control alignment and stable composer insets appear at both sizes. Account follows native Details spacing. Paragraph density partly reflects the deliberately long stress fixture. |
| Typography scale | 9.0 | Semantic body/headline/subheadline styles form a coherent scale. Scaled circles and intrinsic text height preserve long rows. Small light instructional text needs stronger contrast rather than rewritten copy. |
| Dynamic Type | 9.0 | Default/XXXL captures show complete capacity wording, wrapping settings values, guide steps and usable sign-in controls. New size-matched Apple references improve the comparison. Accessibility sizes beyond XXXL remain unobserved. |
| Light contrast | 8.0 | Primary ink and row controls are clear. Actual capacity-hint and sign-in-helper pixels are #8a8a8e on white, approximately 3.44:1, weak for small default text. Disabled fixture controls are excluded from enabled-production judgments. |
| Dark contrast | 9.0 | Primary text, circles and grips are clear on black, and opaque Account groups are coherent. Activity wallpaper diversity and enabled production account/auth controls remain outside the capture evidence. |
| Iconography | 9.2 | Existing SF symbols are consistent and restrained. Circle and grip identify the first line rather than the middle of a paragraph. No branding or icon changes are needed. |
| Safe area / Dynamic Island | 9.0 | Board controls, composer and expanded Activity stay within observed bounds. Keyboard Done participates in layout. Collapsed/minimal Island is intentionally empty; physical sensor/lock verification is absent. |
| Scroll/pull-down / last row | 9.5 | All four bottom-after-pull originals retain full final-row ink above the composer, including the taller wrapping capacity state. Native geometry/ink gates and the full-suite pass support this well. Rejected transition frames are excluded. |
| List rows | 9.0 | Plain full-width rows, first-line circles/grips, intrinsic wrapping and separators read naturally beside Reminders. Source supplies native collection scrolling, swipe completion and accessible reorder actions. |
| Empty states | 9.0 | All Clear and the flat guide are legible before editing; the guide disappears while focused and restores afterward in all four variants. No exact dark/XXXL Apple empty reference exists. |
| Composer ergonomics | 8.1 | The composer is reachable, stable and expands vertically; full-board status wraps as static text. Done is shown only for an empty draft, leaving no explicit draft-preserving keyboard dismissal after typing on an empty board. |
| Keyboard handling | 8.8 | All eight recheck originals show separated Done and alternate-auth controls above real keyboards. Three repetitions plus combined execution passed all 32 cases without observed invalid-frame warnings. The separate nonempty composer dismissal gap limits the whole-app score. |
| Sheet presentation/detents | 9.2 | Account medium/large top/lower states have native groups, drag indicator and reachable Done. XXXL values reflow and the footer reaches the end. Paired Details sheets support material/radius/type coherence despite different semantics. |
| Navigation clarity | 8.7 | Your Board, Account and Sign In are distinct; account dismissal and auth-mode switching are explicit. Populated-board errors offer dismiss but no immediate retry in the banner. |
| Touch targets | 9.2 | Source establishes 44pt board/retry/guide targets and 48pt sign-in Done/alternate controls. Recheck edge taps directly support sign-in hit regions; board checks support row/capacity geometry. Production-only account actions are not all exercised. |
| Haptics | 8.0 | Success/error sensory feedback and drag selection feedback are deliberately wired. Simulator results cannot establish physical strength, timing or consistency; no tactile failure is claimed. |
| Animation/transitions | 8.3 | Board updates use a restrained 0.2s transition with Reduce Motion bypass; guide/native keyboard/sheet behavior is structurally sensible. Still captures and logs do not establish all interactive transition quality. |
| Loading states | 8.7 | Board loading has a labeled native spinner and sign-in pending preserves button geometry with an in-progress accessibility label. No measured real-network latency or prolonged-load recovery sequence is supplied. |
| Error states | 7.8 | Empty-board retry is 44pt and populated errors preserve content; sign-in has understandable existing recovery copy. Board captures expose NSURLErrorDomain error -1009 as the main explanation; Account lacks the deliberate error announcement policy added elsewhere. |
| VoiceOver/labels | 8.3 | Rows, controls, headers and reorder actions have useful source labels; board/sign-in errors deduplicate announcements. Account errors remain a source-derived risk; spoken traversal/focus continuity was not observed. |
| iOS HIG consistency | 8.9 | Native navigation, grouped sheets, content-unavailable views, form semantics and system symbols fit platform conventions. Conditional composer dismissal and raw diagnostic presentation are the main practical polish departures. |
| Lock Screen / Live Activity | 8.8 | Eight native visible surfaces conserve ten originals: banner 5+5/default and 4+6/XXXL; Island 3+7/default and 2+8/XXXL. Footer and bounds are readable. Single-line truncation is explicit; Notification Center is not true physical Lock Screen evidence. |
| Sign-in/onboarding | 8.9 | Flat provider/email grouping, password fallback, inbox recovery and fixed Done inset form a clear flow. Setup instructions remain intact without competing during entry. External actions are blocked in demos; enabled production presentation/authentication are not certified. |
| Settings/account | 8.5 | Medium/large top/lower states are readable; values wrap and the version/footer remain reachable. The persistence explanation is dense at XXXL and Account errors lack an explicit announcement. Demo-disabled rows cannot establish live-action behavior. |
| Performance feel | 8.5 | The bounded board and native collection implementation are appropriate; complete runtime matrices show no invalid-frame issue. No frame-time, launch-time, network or physical interaction measurements support a 9+ claim. |
| Delight | 8.5 | Content-first rows, quiet All Clear and unobtrusive cross-surface reminders offer polish without decoration. Draft dismissal and clearer failure recovery would feel more forgiving. Motion/haptic delight is not inferred from stills. |
| Long text | 9.1 | Long paragraphs remain complete/scrollable, final-row ink is intact, capacity copy wraps and settings/auth helpers reflow. Activity deliberately shows excerpts plus conserved overflow. Nonempty multiline composer and long account identities remain uncaptured. |
| Reduced Motion / Transparency | 8.3 | Source bypasses board animation under Reduce Motion and supplies solid composer/error chrome for reduced transparency/increased contrast. Settings-on native captures and physical testing are absent; this is implementation evidence, not certification. |
| Palette / minimalism | 9.5 | Unboxed board/guide/form surfaces, native settings groups and neutral symbols honor the minimal direction. Red is reserved for existing semantic errors; no decorative orange/red or nested cards were introduced. |

## Previous findings

- **R2A1:** Resolved in observed sign-in layout and repeated edge-tap matrices.
- **R2A2:** Resolved: circle/grip first-line alignment with 44pt regions.
- **R2A3:** Resolved: intrinsic static capacity wording wraps fully; last-row clearance retained.
- **R2A4:** No recurrence in complete recheck plus three repetitions; historical cause is not retrospectively proven.
- **R2A5:** Resolved: flat guide hides during focus and restores after dismissal.
- **R2A6:** Board/sign-in policies improved; Account remains R3A3; spoken behavior remains unobserved.

## Evidence gaps

- True locked physical-device Activity, varied wallpapers and physical Dynamic Island geometry were not observed. Notification Center/native expanded simulator frames establish only those surfaces.
- Physical haptics, spoken VoiceOver traversal/announcements and focus continuity were not tested. Source wiring/unit policies do not certify them.
- Reduce Motion, Reduce Transparency, Increase Contrast and accessibility sizes beyond XXXL were not captured enabled. Localization, RTL and smaller devices are outside the matrix.
- Enabled production auth/account controls, actual authentication, deletion/sign-out errors, permission dialogs and long account identities are absent. Demo-disabled contrast is not a production defect.
- Board composer captures all have empty drafts; nonempty/multiline editing and draft-preserving dismissal need native follow-up.
- No Notes, exact auth or Apple Activity reference exists. Empty dark/XXXL and Account medium/lower references are approximate as pairings disclose.
- No launch/frame-time/network-latency measurements. Four Activity recordings exist; reviewer inspected preserved expanded native frames rather than playback, so makes no timing-quality claim.
- Release and Deno 52+4 are retained historical successes reused by input identity, not fresh recheck runs. Broader Python discovery still lacks initdb.
- Historical 275/1 remains intact; test-only 542b9f7/recheck success does not rewrite it. Other logs/compiler/automation diagnostics remain; no global warning-free claim.

## Screenshot manifest

All paths are relative to this round. All 110 were inspected via nine historical contact sheets and the recheck sheet; original samples included all four bottom-after-pull images, all eight recheck keyboards, guide before/focused/restored, composer, Account medium/large/top/lower, loading/error and native Activity banner/expanded.

- [account-dark-default-top.png](account-dark-default-top.png)
- [account-light-default-top.png](account-light-default-top.png)
- [activity/multiline-dark-XXXL-collapsed.png](activity/multiline-dark-XXXL-collapsed.png)
- [activity/multiline-dark-XXXL-expanded.png](activity/multiline-dark-XXXL-expanded.png)
- [activity/multiline-dark-XXXL-notification-center.png](activity/multiline-dark-XXXL-notification-center.png)
- [activity/multiline-dark-default-collapsed.png](activity/multiline-dark-default-collapsed.png)
- [activity/multiline-dark-default-expanded.png](activity/multiline-dark-default-expanded.png)
- [activity/multiline-dark-default-notification-center.png](activity/multiline-dark-default-notification-center.png)
- [activity/multiline-light-XXXL-collapsed.png](activity/multiline-light-XXXL-collapsed.png)
- [activity/multiline-light-XXXL-expanded.png](activity/multiline-light-XXXL-expanded.png)
- [activity/multiline-light-XXXL-notification-center.png](activity/multiline-light-XXXL-notification-center.png)
- [activity/multiline-light-default-collapsed.png](activity/multiline-light-default-collapsed.png)
- [activity/multiline-light-default-expanded.png](activity/multiline-light-default-expanded.png)
- [activity/multiline-light-default-notification-center.png](activity/multiline-light-default-notification-center.png)
- [composer-dark-default-top.png](composer-dark-default-top.png)
- [composer-light-default-top.png](composer-light-default-top.png)
- [empty-dark-default-top.png](empty-dark-default-top.png)
- [empty-light-default-top.png](empty-light-default-top.png)
- [extras/account-dark-XXXL-large-lower.png](extras/account-dark-XXXL-large-lower.png)
- [extras/account-dark-XXXL-large-top.png](extras/account-dark-XXXL-large-top.png)
- [extras/account-dark-XXXL-medium-lower.png](extras/account-dark-XXXL-medium-lower.png)
- [extras/account-dark-XXXL-medium-top.png](extras/account-dark-XXXL-medium-top.png)
- [extras/account-dark-default-large-lower.png](extras/account-dark-default-large-lower.png)
- [extras/account-dark-default-large-top.png](extras/account-dark-default-large-top.png)
- [extras/account-dark-default-medium-lower.png](extras/account-dark-default-medium-lower.png)
- [extras/account-dark-default-medium-top.png](extras/account-dark-default-medium-top.png)
- [extras/account-light-XXXL-large-lower.png](extras/account-light-XXXL-large-lower.png)
- [extras/account-light-XXXL-large-top.png](extras/account-light-XXXL-large-top.png)
- [extras/account-light-XXXL-medium-lower.png](extras/account-light-XXXL-medium-lower.png)
- [extras/account-light-XXXL-medium-top.png](extras/account-light-XXXL-medium-top.png)
- [extras/account-light-default-large-lower.png](extras/account-light-default-large-lower.png)
- [extras/account-light-default-large-top.png](extras/account-light-default-large-top.png)
- [extras/account-light-default-medium-lower.png](extras/account-light-default-medium-lower.png)
- [extras/account-light-default-medium-top.png](extras/account-light-default-medium-top.png)
- [extras/board-error-empty-dark-XXXL.png](extras/board-error-empty-dark-XXXL.png)
- [extras/board-error-empty-dark-default.png](extras/board-error-empty-dark-default.png)
- [extras/board-error-empty-light-XXXL.png](extras/board-error-empty-light-XXXL.png)
- [extras/board-error-empty-light-default.png](extras/board-error-empty-light-default.png)
- [extras/board-error-populated-dark-XXXL-recovered.png](extras/board-error-populated-dark-XXXL-recovered.png)
- [extras/board-error-populated-dark-XXXL.png](extras/board-error-populated-dark-XXXL.png)
- [extras/board-error-populated-dark-default-recovered.png](extras/board-error-populated-dark-default-recovered.png)
- [extras/board-error-populated-dark-default.png](extras/board-error-populated-dark-default.png)
- [extras/board-error-populated-light-XXXL-recovered.png](extras/board-error-populated-light-XXXL-recovered.png)
- [extras/board-error-populated-light-XXXL.png](extras/board-error-populated-light-XXXL.png)
- [extras/board-error-populated-light-default-recovered.png](extras/board-error-populated-light-default-recovered.png)
- [extras/board-error-populated-light-default.png](extras/board-error-populated-light-default.png)
- [extras/board-loading-dark-XXXL.png](extras/board-loading-dark-XXXL.png)
- [extras/board-loading-dark-default.png](extras/board-loading-dark-default.png)
- [extras/board-loading-light-XXXL.png](extras/board-loading-light-XXXL.png)
- [extras/board-loading-light-default.png](extras/board-loading-light-default.png)
- [extras/guide-dark-XXXL-before.png](extras/guide-dark-XXXL-before.png)
- [extras/guide-dark-XXXL-focused.png](extras/guide-dark-XXXL-focused.png)
- [extras/guide-dark-XXXL-restored.png](extras/guide-dark-XXXL-restored.png)
- [extras/guide-dark-default-before.png](extras/guide-dark-default-before.png)
- [extras/guide-dark-default-focused.png](extras/guide-dark-default-focused.png)
- [extras/guide-dark-default-restored.png](extras/guide-dark-default-restored.png)
- [extras/guide-light-XXXL-before.png](extras/guide-light-XXXL-before.png)
- [extras/guide-light-XXXL-focused.png](extras/guide-light-XXXL-focused.png)
- [extras/guide-light-XXXL-restored.png](extras/guide-light-XXXL-restored.png)
- [extras/guide-light-default-before.png](extras/guide-light-default-before.png)
- [extras/guide-light-default-focused.png](extras/guide-light-default-focused.png)
- [extras/guide-light-default-restored.png](extras/guide-light-default-restored.png)
- [extras/signin-dark-XXXL-default.png](extras/signin-dark-XXXL-default.png)
- [extras/signin-dark-XXXL-error.png](extras/signin-dark-XXXL-error.png)
- [extras/signin-dark-XXXL-inbox.png](extras/signin-dark-XXXL-inbox.png)
- [extras/signin-dark-XXXL-keyboard.png](extras/signin-dark-XXXL-keyboard.png)
- [extras/signin-dark-XXXL-loading.png](extras/signin-dark-XXXL-loading.png)
- [extras/signin-dark-XXXL-password-keyboard.png](extras/signin-dark-XXXL-password-keyboard.png)
- [extras/signin-dark-XXXL-password.png](extras/signin-dark-XXXL-password.png)
- [extras/signin-dark-default-default.png](extras/signin-dark-default-default.png)
- [extras/signin-dark-default-error.png](extras/signin-dark-default-error.png)
- [extras/signin-dark-default-inbox.png](extras/signin-dark-default-inbox.png)
- [extras/signin-dark-default-keyboard.png](extras/signin-dark-default-keyboard.png)
- [extras/signin-dark-default-loading.png](extras/signin-dark-default-loading.png)
- [extras/signin-dark-default-password-keyboard.png](extras/signin-dark-default-password-keyboard.png)
- [extras/signin-dark-default-password.png](extras/signin-dark-default-password.png)
- [extras/signin-light-XXXL-default.png](extras/signin-light-XXXL-default.png)
- [extras/signin-light-XXXL-error.png](extras/signin-light-XXXL-error.png)
- [extras/signin-light-XXXL-inbox.png](extras/signin-light-XXXL-inbox.png)
- [extras/signin-light-XXXL-keyboard.png](extras/signin-light-XXXL-keyboard.png)
- [extras/signin-light-XXXL-loading.png](extras/signin-light-XXXL-loading.png)
- [extras/signin-light-XXXL-password-keyboard.png](extras/signin-light-XXXL-password-keyboard.png)
- [extras/signin-light-XXXL-password.png](extras/signin-light-XXXL-password.png)
- [extras/signin-light-default-default.png](extras/signin-light-default-default.png)
- [extras/signin-light-default-error.png](extras/signin-light-default-error.png)
- [extras/signin-light-default-inbox.png](extras/signin-light-default-inbox.png)
- [extras/signin-light-default-keyboard.png](extras/signin-light-default-keyboard.png)
- [extras/signin-light-default-loading.png](extras/signin-light-default-loading.png)
- [extras/signin-light-default-password-keyboard.png](extras/signin-light-default-password-keyboard.png)
- [extras/signin-light-default-password.png](extras/signin-light-default-password.png)
- [full-dark-default-bottom-after-pull.png](full-dark-default-bottom-after-pull.png)
- [full-dark-default-top.png](full-dark-default-top.png)
- [full-light-default-bottom-after-pull.png](full-light-default-bottom-after-pull.png)
- [full-light-default-top.png](full-light-default-top.png)
- [long-text-dark-XXXL-bottom-after-pull.png](long-text-dark-XXXL-bottom-after-pull.png)
- [long-text-dark-XXXL-top.png](long-text-dark-XXXL-top.png)
- [long-text-dark-default-top.png](long-text-dark-default-top.png)
- [long-text-light-XXXL-bottom-after-pull.png](long-text-light-XXXL-bottom-after-pull.png)
- [long-text-light-XXXL-top.png](long-text-light-XXXL-top.png)
- [long-text-light-default-top.png](long-text-light-default-top.png)
- [signin-dark-default-top.png](signin-dark-default-top.png)
- [signin-light-default-top.png](signin-light-default-top.png)
- [recheck/signin-light-default-keyboard.png](recheck/signin-light-default-keyboard.png)
- [recheck/signin-light-default-password-keyboard.png](recheck/signin-light-default-password-keyboard.png)
- [recheck/signin-light-XXXL-keyboard.png](recheck/signin-light-XXXL-keyboard.png)
- [recheck/signin-light-XXXL-password-keyboard.png](recheck/signin-light-XXXL-password-keyboard.png)
- [recheck/signin-dark-default-keyboard.png](recheck/signin-dark-default-keyboard.png)
- [recheck/signin-dark-default-password-keyboard.png](recheck/signin-dark-default-password-keyboard.png)
- [recheck/signin-dark-XXXL-keyboard.png](recheck/signin-dark-XXXL-keyboard.png)
- [recheck/signin-dark-XXXL-password-keyboard.png](recheck/signin-dark-XXXL-password-keyboard.png)

## Paired references

The 110-state mappings/mismatches remain in [pairings.json](pairings.json) and [pairings.md](pairings.md). These 17 paths exist and exclude rejected transitions.

- [../../reference/reminders-bottom-dark.png](../../reference/reminders-bottom-dark.png)
- [../../reference/reminders-compose-light.png](../../reference/reminders-compose-light.png)
- [../../reference/reminders-empty-light.png](../../reference/reminders-empty-light.png)
- [../../reference/reminders-sheet-dark.png](../../reference/reminders-sheet-dark.png)
- [../../reference/reminders-top-light.png](../../reference/reminders-top-light.png)
- [../../reference/round2/reminders-bottom-light.png](../../reference/round2/reminders-bottom-light.png)
- [../../reference/round2/reminders-compose-dark.png](../../reference/round2/reminders-compose-dark.png)
- [../../reference/round2/reminders-sheet-light.png](../../reference/round2/reminders-sheet-light.png)
- [../../reference/round2/reminders-top-dark.png](../../reference/round2/reminders-top-dark.png)
- [../../reference/round3/reminders-bottom-dark-XXXL.png](../../reference/round3/reminders-bottom-dark-XXXL.png)
- [../../reference/round3/reminders-bottom-light-XXXL.png](../../reference/round3/reminders-bottom-light-XXXL.png)
- [../../reference/round3/reminders-compose-dark-XXXL.png](../../reference/round3/reminders-compose-dark-XXXL.png)
- [../../reference/round3/reminders-compose-light-XXXL.png](../../reference/round3/reminders-compose-light-XXXL.png)
- [../../reference/round3/reminders-sheet-dark-XXXL.png](../../reference/round3/reminders-sheet-dark-XXXL.png)
- [../../reference/round3/reminders-sheet-light-XXXL.png](../../reference/round3/reminders-sheet-light-XXXL.png)
- [../../reference/round3/reminders-top-dark-XXXL.png](../../reference/round3/reminders-top-dark-XXXL.png)
- [../../reference/round3/reminders-top-light-XXXL.png](../../reference/round3/reminders-top-light-XXXL.png)

## Validation provenance

- [checks.json](checks.json)
- [../../validation/round3/recheck/REPORT.md](../../validation/round3/recheck/REPORT.md)
- [../../validation/round3/recheck/combined-summary.json](../../validation/round3/recheck/combined-summary.json)
- [../../validation/round3/recheck/matrix-proof.json](../../validation/round3/recheck/matrix-proof.json)
- [../../validation/round3/recheck/build-Debug.json](../../validation/round3/recheck/build-Debug.json)
- [activity/pipeline-light-default.json](activity/pipeline-light-default.json)

Written by gpt-6-astra in Codex on behalf of Edmund
