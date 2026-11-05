# Round 8 independent UI/UX review — gpt-6.1-sol

Overall **8.57/10**. Minimum **7.50**, Sign-in/onboarding. This is the arithmetic mean of the exact 30 rubric categories, rounded to two decimals.

Credentials first, fixed loading geometry, measured focus settlement and Account prefix emphasis are useful improvements. The board and Account are comparatively calm; the complete sign-in composition still feels crowded and horizontally banded. Passing geometry checks do not establish aesthetic acceptance.

Model: gpt-6.1-sol, high reasoning, Codex. Round 8 source: `20ae77e29019444a499e9e47c98d6b656ef56819`. Source identity: `sha256:a2449d961c428fc781cea0c751f3406e3e0e499350000d32bc4eca2fbfa0d76f`. Production acquisition revision: `46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4`; supplied metadata HEAD `ca1307e`.

Independent source and captured-evidence review; no device operation, implementation, build, Git operation or peer numerical score access.

## Category scores

| Category | Score | Rationale |
|---|---:|---|
| Visual hierarchy | 7.9 | The board and Account hierarchy are coherent; sign-in still stacks too many similarly weighted horizontal elements. |
| Spacing/grid | 8.1 | Most margins and rows are consistent; the authentication composition needs a more deliberate grouping rhythm. |
| Typography scale | 8.7 | System type is legible and restrained, with clear headers and body text. |
| Dynamic Type | 8.6 | XXXL is usable across the captured surfaces; larger accessibility sizes lack native evidence. |
| Light contrast | 9.0 | Primary information reads clearly in light mode. |
| Dark contrast | 8.8 | Dark content is readable, though authentication contrast distribution is visually unbalanced. |
| Iconography | 9.0 | Icons are familiar, quiet and meaningful. |
| Safe area / Dynamic Island | 9.1 | Captured app controls and expanded Activity content respect system regions. |
| Scroll/pull-down / last row | 8.5 | Last-row reachability is strong; the top edge still looks custom and imperfect. |
| List rows | 8.8 | Rows provide a calm, readable task surface. |
| Empty states | 8.7 | The empty state explains what happens next without decorative framing. |
| Composer ergonomics | 9.0 | The bottom composer is clear and stays close to the keyboard. |
| Keyboard handling | 8.4 | Primary focus geometry works; peripheral provider clipping weakens the settled composition. |
| Sheet presentation/detents | 8.9 | Account sheets feel native and remain navigable at both detents. |
| Navigation clarity | 8.7 | Core destinations and actions are understandable. |
| Touch targets | 9.2 | Source and supplied geometry support generous key controls. |
| Haptics | 7.8 | The implementation uses sensible semantic feedback; tactile quality is unobserved. |
| Animation/transitions | 8.0 | Sampled transitions preserve context, but the evidence cannot establish continuous motion quality. |
| Loading states | 9.0 | Loading communicates progress without moving following authentication controls. |
| Error states | 8.5 | Messages are readable and recovery is available; credential-error placement is detached. |
| VoiceOver/labels | 8.4 | Source semantics are deliberate; spoken experience remains unverified. |
| iOS HIG consistency | 8.6 | The product mostly uses native surfaces with limited custom polish debt. |
| Lock Screen / Live Activity | 8.7 | The captured Activity surfaces are compact, legible and honest about overflow. |
| Sign-in/onboarding | 7.5 | The email-first flow is clearer, but the full composition still falls short of calm native polish. |
| Settings/account | 8.8 | Account is orderly and the small prefix change improves guidance scanning. |
| Performance feel | 8.2 | There is no established runtime responsiveness defect, but hardware feel is not measured. |
| Delight | 7.8 | The board has quiet utility; authentication lacks the same effortless finish. |
| Long text | 8.9 | Captured long content is robust and remains readable. |
| Reduced Motion / Transparency | 8.7 | Captured combined settings remain usable and source respects the major preferences. |
| Palette / minimalism | 8.9 | The palette is restrained and mostly semantic. |

## Independent screenshot and source assessments

### Visual hierarchy — 7.9

Screenshot assessment: Login composition originals show a bright native Apple slab competing with the credential CTA, especially in dark empty and password states. Reminders references keep one dominant task region.

Source assessment: SignInView makes email contiguous and secondary providers explicit, but 24pt outer spacing, a Divider, 20pt form groups and a centered mode switch still accumulate visual bands.

### Spacing/grid — 8.1

Screenshot assessment: Board rows align on a stable text column; Account grouped insets look native. Default login has a large provider break while XXXL password content fills nearly the whole viewport.

Source assessment: Explicit 20pt sign-in margins and nested 8/12/20/24pt gaps are predictable, but the mode-switch hit area and separator add height beyond the useful credential cluster.

### Typography scale — 8.7

Screenshot assessment: Default and XXXL text preserve readable line breaks. Account Home Screen and Lock Screen prefixes now aid scanning; provider labels remain comparatively forceful.

Source assessment: Semantic title2/headline/body/footnote styles and scaled metrics support consistent sizing; the Apple SDK asset retains its native typography.

### Dynamic Type — 8.6

Screenshot assessment: Long rows and expanded instructions wrap without observed horizontal clipping. Password heading remains above the secure field on first focus and refocus.

Source assessment: Scaled metrics, vertical text growth, native list self-sizing and measured focus settlement support the evidence. AX1–AX5 unit renders do not establish device layout.

### Light contrast — 9.0

Screenshot assessment: Enabled login labels, board ink, errors and Account guidance remain distinct. Disabled fixture controls are identified as disabled rather than mistaken for production contrast failures.

Source assessment: System semantic colors and primary-opacity helper text are appropriate. Recorded instruction samples exceed 7:1; enabled primary action checks exceed 4.5:1.

### Dark contrast — 8.8

Screenshot assessment: White board text and Account instructions are clear. The white native Apple button draws more attention than the empty credential action, even though its label is crisp.

Source assessment: Semantic foregrounds are sound; whiteOutline is intentionally fixed for the Apple asset. Disabled preview paint is separated from enabled inert composition fixtures.

### Iconography — 9.0

Screenshot assessment: Completion circles, Account glyphs, keyboard dismissal and disclosure arrows have recognizable meanings. Red appears on the destructive trash icon, not as decoration.

Source assessment: SF Symbols and the native SignInWithAppleButton are retained. Decorative glyphs are generally hidden from accessibility while controls have explicit labels.

### Safe area / Dynamic Island — 9.1

Screenshot assessment: Top controls sit below status/Island space; expanded Activity text and overflow footer clear the curved lower edge in representative originals.

Source assessment: Native navigation and safeAreaInset handle app chrome. Empty compact Island regions avoid widened status overlap; expanded content has its own height budget and bottom margin.

### Scroll/pull-down / last row — 8.5

Screenshot assessment: Scrolled long/XXXL final rows retain their final ink above capacity guidance. Some partial-scroll states retain faint departing text immediately under the title area.

Source assessment: UIKit refresh/reorder integration and hidden bottom edge preserve the last row. A custom 24pt gradient mask explains the remaining top fragments; the test checks only the narrow initial band.

### List rows — 8.8

Screenshot assessment: Text aligns with completion circles on the first line; long rows expand and separators remain subtle. Persistent six-dot grips reduce text width and add some repeated furniture.

Source assessment: A plain UICollectionView list with UIHostingConfiguration gives native self-sizing, separate 44pt completion/grip regions and explicit accessible reorder actions.

### Empty states — 8.7

Screenshot assessment: All Clear reads clearly and the one-time setup guidance is useful. Compared with the sparse Reminders empty reference, the guidance adds density but remains coherent.

Source assessment: ContentUnavailableView and a dismissible, persisted tip are appropriate. Guidance hides during focused composition and on loading/error/populated states.

### Composer ergonomics — 9.0

Screenshot assessment: Empty and nonempty XXXL composer originals retain draft text, a distinct add button and an unobstructed keyboard-dismiss action.

Source assessment: A bottom safe-area inset, 1–4 line field, scaled visual button and minimum 44pt target are sensible. Capacity replaces the input instead of leaving a focusable dead field.

### Keyboard handling — 8.4

Screenshot assessment: First-focus/refocus movie frames retain Password and helper context above the keyboard. At XXXL, the Done strip can cut through the Apple button and leave a partial provider shape.

Source assessment: Focus-frame preferences and scroll-idle restoration address heading settlement. The focused group alone is bounded; provider controls are not included in the settlement rule.

### Sheet presentation/detents — 8.9

Screenshot assessment: Medium and large examples retain title, Done and scroll reachability. Native grouped surfaces resemble the Reminders sheet references without nested custom cards.

Source assessment: Native medium/large presentation detents, visible drag indicator and scroll content interaction are suitable. Destructive work blocks dismissal while busy.

### Navigation clarity — 8.7

Screenshot assessment: Your Board, Account and Sign In are unambiguous. The login mode-switch and provider choices are all visible but compete for attention.

Source assessment: NavigationStack and native toolbar placement are clear. Explicit Account hints and password/link mode labels preserve meaning; no live external navigation was observed.

### Touch targets — 9.2

Screenshot assessment: Completion, reorder, add, Account and Done targets appear comfortably separated in representative captures.

Source assessment: The source uses explicit 44pt or 48pt regions; current UI checks verify native frames for priority controls. No claim is made for uncaptured physical touch accuracy or every link width.

### Haptics — 7.8

Screenshot assessment: Screenshots and movies provide no tactile evidence.

Source assessment: Success/error sensory feedback and a selection generator on drag start are appropriate choices. Physical strength, timing and interaction with device settings still require hardware observation.

### Animation/transitions — 8.0

Screenshot assessment: Three actual samples per movie show expanded Island, dismissal, keyboard/refocus and app-close states. Some samples fall mid-system transition; they are not app defects by themselves.

Source assessment: Short board animations respect Reduce Motion and UIKit handles reorder movement. reloadData and focus-driven scrollTo deserve real continuous observation; the recorded XCTest notification waits have no diagnosed UI cause.

### Loading states — 9.0

Screenshot assessment: Native spinner ink is visible in pending fixtures and the following mode switch/providers remain aligned with resting states.

Source assessment: The title remains in layout with opacity zero and a regular ProgressView overlay; accessible labels retain the action plus in-progress meaning. Busy guards prevent duplicate submission.

### Error states — 8.5

Screenshot assessment: Board and Account errors wrap cleanly with accessible contrast. Sign-in failure text sits after both providers, far from the credential action that caused it.

Source assessment: Announcement policies deduplicate errors and reset on recovery. The sign-in error placement follows providerSection; moving it into the active credential cluster would improve association while preserving every word. Raw network-error wording is explicitly retained.

### VoiceOver/labels — 8.4

Screenshot assessment: Visible labels correspond to the intended actions, but images cannot establish traversal order or spoken clarity.

Source assessment: Completion labels include reminder text, grip actions expose position/moves, duplicate row text is hidden, fields are named and announcement policies avoid repeats. The persistent visual Password heading is accessibilityHidden to prevent duplication.

### iOS HIG consistency — 8.6

Screenshot assessment: Native lists, sheets, semantic glyphs and system typography fit the platform. Login still reads like a custom vertical form and the board top fade is less convincing than native reference chrome.

Source assessment: The architecture uses native components where useful. Custom gradient masking, mixed authentication button shapes and the separate Done inset are the main departures requiring visual judgment.

### Lock Screen / Live Activity — 8.7

Screenshot assessment: Short lines and +N more footers fit the Lock Screen-like banner and expanded Island in light/dark default/XXXL. Long lines truncate by design rather than overflowing.

Source assessment: Separate line/height budgets and forced dark expanded-Island text are sound. Native background material is preserved. True lock, arbitrary wallpapers, privacy states and accessibility-size device behavior are unobserved.

### Sign-in/onboarding — 7.5

Screenshot assessment: All 60 named comparisons show the changed order/grouping; default empty/filled originals remain banded, and password XXXL becomes a dense form followed by two strong provider controls.

Source assessment: Contiguous credentials, neutral prompts, fixed pending footprint and measured focus settlement are meaningful improvements. These do not solve overall hierarchy or the placement of auth errors. Preview actions are inert, so authentication success is not evidenced.

### Settings/account — 8.8

Screenshot assessment: Identity is passive, sections are native, Home Screen/Lock Screen prefixes are discernible, and lower support/destructive content is reachable. Expanded guidance remains text-heavy at XXXL.

Source assessment: Native insetGrouped List, minimum row heights and attributed prefix emphasis preserve exact text. Refresh/session error paths announce and recover; five Settings methods independently restored recorded originals in supplied evidence.

### Performance feel — 8.2

Screenshot assessment: Movie samples show expected endpoint states and stable focused headings; sparse samples cannot reveal dropped frames or latency.

Source assessment: Current unfiltered suite passes. Five-sample simulator launch/scroll metrics are host/XCTest measurements, not device frame-pacing evidence. Historical notification waits remain unexplained and are not reclassified as an app hang.

### Delight — 7.8

Screenshot assessment: All Clear, the compact composer and subtle Account layout feel considered. Repeated login bars and partially exposed provider controls interrupt that calm.

Source assessment: Semantic feedback and restrained short animations support polish. There is no need for decorative color or extra cards; simplifying existing composition would help most.

### Long text — 8.9

Screenshot assessment: XXXL final board rows retain final lines, instructions wrap, and legal links can be scrolled into view. Activity deliberately tail-truncates per-line previews and reports overflow.

Source assessment: Self-sizing rows, fixedSize vertical helpers, scrollable forms and surface-specific Activity budgets support the observed results. Unbounded real email/provider captions and AX1–AX5 native states remain outside evidence.

### Reduced Motion / Transparency — 8.7

Screenshot assessment: Combined light/dark default/XXXL error and focus states preserve contrast and headings. The packet records actual native setting restoration, not only launch flags.

Source assessment: Board animation bypasses under Reduce Motion; chrome uses solid alternatives for transparency/contrast. The top mask changes to a short hard boundary. Continuous reduced-motion behavior and Activity on arbitrary backgrounds are not established.

### Palette / minimalism — 8.9

Screenshot assessment: White/black/gray dominate; indigo identifies credential actions, and red is confined to destructive state. There are no nested custom cards or decorative red/orange surfaces.

Source assessment: System colors and primary/secondary styles avoid palette sprawl. Remaining visual density comes from layout and repeated control surfaces, not a need for more decoration.

## Findings

### R8-SOL-01 — The credential-first composition still has competing horizontal bands

Severity: **medium**. Screen: Sign In — empty/filled default and password, light/dark, default/XXXL. Confidence: **high**. Basis: observed and source-derived.

Moving credentials first establishes a useful reading order. The full screen nevertheless reads as field slab, CTA slab, centered mode-switch band, divider, Apple slab, Google outline and legal band. In the dark empty form the native white Apple control dominates the selected email path; at XXXL password size the same ingredients fill the page densely. This is a composition finding, not a failed geometry assertion.

Evidence: [native/LoginCompositionUITests/8123BBD3-0830-4980-9D0D-457AE321FD45.png](native/LoginCompositionUITests/8123BBD3-0830-4980-9D0D-457AE321FD45.png), [native/LoginCompositionUITests/77E91E1D-B982-40F5-8AF2-AD0E900D6951.png](native/LoginCompositionUITests/77E91E1D-B982-40F5-8AF2-AD0E900D6951.png), [native/LoginCompositionUITests/B4F5313C-7E8C-400C-8074-55CBC7C0E1F5.png](native/LoginCompositionUITests/B4F5313C-7E8C-400C-8074-55CBC7C0E1F5.png), [native/LoginCompositionUITests/787638D3-71C9-4C7B-82A7-0AED93E1460E.png](native/LoginCompositionUITests/787638D3-71C9-4C7B-82A7-0AED93E1460E.png), [native/LoginCompositionUITests/C913ABC7-7621-421D-8683-3FF306659815.png](native/LoginCompositionUITests/C913ABC7-7621-421D-8683-3FF306659815.png), [native/LoginCompositionUITests/2E1050E6-DDAE-42E7-A64A-D64F485CFA12.png](native/LoginCompositionUITests/2E1050E6-DDAE-42E7-A64A-D64F485CFA12.png).

Source: ios/App/SignInView.swift: body, emailSection, providerSection, SignInSection.

Concrete fix: Keep the native Apple asset, branding, exact words and Apple-then-Google order. Tighten the active field-to-submit cluster to a deliberate 12–16pt rhythm, give the password/link mode switch a quieter leading-aligned typographic treatment with its existing >=44pt hit area, and use one clear spatial break before the provider pair. Reassess whether the divider is still necessary. Review the whole default and password composition together rather than optimizing each gap independently.

Measurable regression check: Recapture the 16 enabled inert composition cases. Retain >=44pt targets, exact copy/provider order, >=4.5:1 active labels, no horizontal clipping and legal-footer reachability; compare the complete screen at native scale for a clear active credential cluster and secondary provider group. Existing 325-test suite must continue passing; taste requires visual acceptance.

### R8-SOL-02 — The keyboard Done strip slices through a provider control

Severity: **low**. Screen: Sign In — XXXL empty-password first focus and refocus, normal and combined settings. Confidence: **high**. Basis: observed and source-derived.

Password, its field/helper and the selected action remain visible. The bright Apple button is partially exposed and then abruptly clipped by the opaque Done strip above the keyboard. Other sizes can expose a Google fragment. This makes the focused screen look unfinished despite correct primary focus geometry; it is not evidence that the Password heading is lost.

Evidence: [keyboard-video-frames/first-focus-normal-light-XXXL-0.png](keyboard-video-frames/first-focus-normal-light-XXXL-0.png), [keyboard-video-frames/first-focus-normal-light-XXXL-1.png](keyboard-video-frames/first-focus-normal-light-XXXL-1.png), [keyboard-video-frames/first-focus-normal-dark-XXXL-0.png](keyboard-video-frames/first-focus-normal-dark-XXXL-0.png), [keyboard-video-frames/first-focus-normal-dark-XXXL-1.png](keyboard-video-frames/first-focus-normal-dark-XXXL-1.png), [keyboard-video-frames/first-focus-combined-light-XXXL-0.png](keyboard-video-frames/first-focus-combined-light-XXXL-0.png), [keyboard-video-frames/first-focus-combined-dark-XXXL-1.png](keyboard-video-frames/first-focus-combined-dark-XXXL-1.png), [../../validation/round8/video-inspection-3.jpg](../../validation/round8/video-inspection-3.jpg), [../../validation/round8/video-inspection-4.jpg](../../validation/round8/video-inspection-4.jpg).

Source: ios/App/SignInView.swift: safeAreaInset(edge: .bottom), restoreFocusedGroup, keyboardDidShowNotification.

Concrete fix: Resolve the focused viewport as a composition: attach Done through native keyboard toolbar behavior and tune focused scroll padding/settlement so the provider block is either fully outside the settled viewport or fully visible above Done. Preserve scrolling access to all provider choices, the native asset and the 48pt Done target.

Measurable regression check: Capture first focus, Done dismissal and refocus for empty/filled password at default/XXXL, both appearances and actual combined settings. Measure the settled viewport and provider frames: a provider visible at rest must not be cut across its label or rounded button by the Done surface. Retain existing heading/field/alternate-action bounds and all current focus assertions.

### R8-SOL-03 — Departing row text leaves a faint custom-looking top fragment

Severity: **low**. Screen: Board — long rows after partial scroll and pull, light/dark XXXL. Confidence: **medium**. Basis: observed and source-derived.

Some departing row lines remain as pale, still-recognizable fragments directly below the title region. The actual Reminders references also soften departing content, so the presence of an edge effect alone is not a defect; Notepad's separate fade and clipped viewport feel less integrated with its navigation chrome. Complete final-row ink remains intact.

Evidence: [native/BoardEdgeAccessibilityUITests/4AB6685C-6CE0-40A2-BDD4-C5F12C82769D.png](native/BoardEdgeAccessibilityUITests/4AB6685C-6CE0-40A2-BDD4-C5F12C82769D.png), [native/BoardCapacityDensityUITests/FFDFD024-F2A7-44B0-A9E9-F258678BD739.png](native/BoardCapacityDensityUITests/FFDFD024-F2A7-44B0-A9E9-F258678BD739.png), [native/HillclimbCaptureUITests/8DDB9F64-FC68-4399-B3CB-02D5B3BB4F13.png](native/HillclimbCaptureUITests/8DDB9F64-FC68-4399-B3CB-02D5B3BB4F13.png).

Source: ios/App/ReorderableReminderList.swift: BoardCollectionView.layoutSubviews and topMask; ios/UITests/BoardEdgeAccessibilityUITests.swift: testTopBandAfterRealPullAndPartialScrollMatrix.

Concrete fix: Revisit the custom gradient layer together with the native navigation scroll-edge relationship. Prefer one coordinated native scroll-edge treatment, or an intentional solid boundary under reduced-transparency settings, rather than independent masks. Keep all final-row and composer clearance behavior.

Measurable regression check: Sweep settled partial-scroll offsets through at least 0–100pt in light/dark default/XXXL and combined settings. Inspect the whole first 24pt of the list edge, not only the current 14-pixel test band; record contrast and glyph extents so no isolated crisp fragment sits outside the intended edge treatment. Retain last-row ink, top safe-area and pull-refresh checks.

### R8-SOL-04 — Credential recovery text is separated from the action that needs recovery

Severity: **low**. Screen: Sign In — authentication failure notice. Confidence: **high**. Basis: observed and source-derived.

The failure message is readable but appears beneath both provider buttons. A user correcting email/password must scan past unrelated alternative actions to find the explanation. This finding concerns placement only; the exact original wording, including Edmund's retained raw network errors elsewhere, stays unchanged.

Evidence: [native/ErrorContrastUITests/EE64DC6F-2D45-4E73-A735-51AECAB33D05.png](native/ErrorContrastUITests/EE64DC6F-2D45-4E73-A735-51AECAB33D05.png), [native/AccessibilitySettingsUITests/94BC1ADA-58E9-41C0-88E6-D9B98A696BC0.png](native/AccessibilitySettingsUITests/94BC1ADA-58E9-41C0-88E6-D9B98A696BC0.png).

Source: ios/App/SignInView.swift: body places error Label after providerSection.

Concrete fix: Place the existing authentication notice immediately after the active credential action group and before the provider separator, while preserving exact wording, icon and announcement policy. Keep provider-specific errors near the provider action if an existing state distinguishes them.

Measurable regression check: Recapture failure/cleared/reappeared cases in light/dark default/XXXL and combined settings. Require complete notice wrapping and >=4.5:1 text, no duplicate announcements, and credential-action -> notice -> provider ordering for credential errors; retain all existing exact-copy and error-reset checks.

## Coverage and evidence boundaries

All 28 canonical contact sheets (page-01 through page-28) were inspected, covering all 332 canonical screenshot paths. The attached JSON explicitly enumerates every canonical path and all 17 actual Reminders reference paths relative to this round directory. It also enumerates the 45 independently opened originals, 38 full-resolution reopens, all 60 same-state login pair names, the 16 movie paths and their three actual sample times each. No 522-acquisition repeat credit is awarded. Twelve unit renders remain separate.

All 16 enabled LoginComposition states were opened as originals; this includes default empty/filled light/dark. Every captured family had representative full-resolution inspection, including all eight XXXL empty-password first-focus/refocus normal/combined frames. All 17 actual Reminders reference originals were opened. All 60 named before/after login pairs were compared on in-memory sheets. Four video inspection sheets show 48 actual samples across 16 movies; this is sampled motion inspection, not continuous playback.

The SwiftUI/source review covered the board, UIKit row bridge, composer, sign-in, Account, persistence guidance, chrome, Activity, geometry/demo fixtures and relevant layout/focus/accessibility tests. Only SignInView and BoardPersistenceSection changed in production. The JSON lists files read fully. Test assertions were considered separately from visual acceptance.

## Validation

The supplied current unfiltered run passes **325/325**: 263 unit and 62 UI, zero failures/skips. All 317 baseline IDs remain, including retained 308/307/304/293 baselines. All 31 required checks pass. The nonrequired manual pinned-driver path remains failed because of stale ownership; the runner supplied the evidence.

The historical 322/2 failure and measured-heading 323/1 failure remain failed. The first correction measured heading geometry; the later failure was a combined matrix timeout after two roughly 60-second XCTest animation-notification waits. No app hang or host cause was diagnosed. The timeout bypassed teardown and left 1/1/1/1 setting drift; explicit recovery restored the recorded 0/1/0/0 originals. The current test-only revision splits the eight configurations while retaining assertions/actions and 240/300-second limits; the final unfiltered run passes 325.

All five Settings methods independently restored the recorded originals: Reduce Motion 0 / Auto-Play Message Effects 1 / Reduce Transparency 0 / Increase Contrast 0. Fresh supplied Release, Python 23, Deno 52+4 and binary/source checks pass. Account instruction contrast samples are at least 8.51:1 dark and 10.37:1 light. Exact full Home Screen/Lock Screen text is retained.

This reviewer independently verified all 96 frozen source input hashes, all 332 canonical image hashes, all 17 reference hashes and all 16 movie hashes, without mismatches. Exact category names, report evidence paths, unique screenshot count and arithmetic were checked. Builds, suites and device actions were not rerun by this reviewer. Exact supplied command arrays, results and source SHA are recorded in the accompanying JSON. Commands/results/source binding remain in the linked supplied evidence: [checks](checks.json), [acceptance](../../tasks/login-focus-polish/acceptance.json), [source binding](../../validation/round8/source-binding.json), [runtime observations](../../validation/round8/runtime-observations.md).

## Evidence gaps

- Notes is unavailable. The 17 actual Apple Reminders references support comparison of native spacing, typography, list edges and sheet chrome; they do not provide exact semantic counterparts for authentication, Live Activity, capacity, medium-detent or combined-settings states.
- No physical haptic observation, spoken VoiceOver session, truly locked-phone capture, arbitrary wallpaper testing, native AX1–AX5 device states, live authentication/account/AutoFill completion or hardware frame-pacing evidence.
- Enabled sign-in composition fixtures use inert local actions. They establish enabled paint and layout, not successful authentication.
- Protected XCTest secure-keyboard stills are partial. Separate actual keyboard movie frames show first focus/refocus and are reviewed independently; partial stills are not full keyboard evidence.
- Motion review consists of 48 actual sampled frames, three for each of 16 movies. There was no continuous playback assessment; no frame-pacing or dropped-frame claim follows.
- Five-sample simulator launch/scroll measurements reflect host/XCTest conditions. They do not prove a hardware responsiveness improvement.
- New filled loading-stability fixtures have no exact Round 7 filled/pending counterpart; new empty-password focus/refocus methods have no identical Round 7 method. The 60 paired states are scoped to their named deterministic fixtures.
- Twelve unit renders are separate from the 332 canonical native screenshots. Source inspection of Activity layout tests does not establish native accessibility-size geometry.
- Source and evidence hashes were independently checked, but supplied builds and test runs were not rerun by this reviewer.

The exact wording, branding, icons and native Apple asset are preserved in all proposed fixes; Apple remains before Google. Raw network-error wording is explicitly retained. No score is adjusted to satisfy a target, and this reviewer does not determine the stop gate.

Written by gpt-6.1-sol in Codex on behalf of Edmund
