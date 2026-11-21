# Round 8 independent UI/UX review

**Overall: 8.40/10. Minimum: 7.3/10 — Sign-in/onboarding.**

Model: **gpt-6-astra**, reasoning effort **high**, harness **Codex**. Round **8**. App/test source `20ae77e29019444a499e9e47c98d6b656ef56819`; source identity `sha256:a2449d961c428fc781cea0c751f3406e3e0e499350000d32bc4eca2fbfa0d76f`. Production revision `46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4`; packet metadata HEAD `ca1307e`.

The board and Account have a solid native foundation. Email-first ordering, measured password-focus settlement and fixed loading footprint improve sign-in, but its overall hierarchy still feels crowded. Native polish is uneven rather than blocked by a demonstrated functional failure. Geometry/tests are evidence of correctness, not aesthetic acceptance.

Email-first ordering is clearer in the 60 same-state comparisons. The default empty and filled screens still look like a succession of similarly weighted horizontal controls. At XXXL, the fixed password heading now survives first focus and refocus; that is a concrete improvement. It does not by itself make the whole screen feel composed. Home Screen/Lock Screen prefix emphasis also helps, without resolving the density of expanded Account guidance. Only SignInView and BoardPersistenceSection production code changed this round.

The arithmetic is **252.1 / 30 = 8.403333…**, rounded to **8.40**. These are independent scores, with no adjustment toward a target. The stop gate is outside this review.

## Category assessments

Screenshot and source assessments are deliberately separate. Haptics, spoken VoiceOver and performance feel remain limited by the evidence described below.

| Category | Score | Rationale |
|---|---:|---|
| Visual hierarchy | 7.6 | Board hierarchy is clear; sign-in still splits attention among several similarly prominent horizontal bands. |
| Spacing/grid | 7.8 | Alignment is consistent, but grouping is less intentional on sign-in and expanded Account. |
| Typography scale | 8.5 | System text is readable and scales coherently, with a little too much equal emphasis in login. |
| Dynamic Type | 8.5 | Default and XXXL are convincingly covered; larger accessibility categories remain unproven. |
| Light contrast | 8.7 | Active text and actions read well; pending feedback is weak. |
| Dark contrast | 8.6 | Strong primary text and neutral surfaces work, but pending-state emphasis is uneven. |
| Iconography | 9.0 | Native and restrained symbols communicate roles well. |
| Safe area / Dynamic Island | 9.0 | Main controls and Activity content respect the measured device geometry. |
| Scroll/pull-down / last row | 9.0 | Last-row legibility and refresh settlement are strong; top-edge fade is slightly untidy. |
| List rows | 8.7 | Rows are readable, spacious and mechanically coherent. |
| Empty states | 8.3 | The next action is clear, but setup instructions dominate the otherwise calm empty board. |
| Composer ergonomics | 8.9 | Composer is accessible and well separated from the list. |
| Keyboard handling | 8.2 | Focus settlement works, while the provider/Done boundary is visually awkward. |
| Sheet presentation/detents | 8.9 | Account uses a coherent native sheet with appropriate expansion. |
| Navigation clarity | 8.8 | The limited navigation is understandable. |
| Touch targets | 9.0 | Measured targets and visible spacing are strong within tested states. |
| Haptics | 7.5 | Intent is sensible, but physical feel cannot be established from this packet. |
| Animation/transitions | 7.8 | Sampled transitions show no gross layout failure, but motion quality is only partially evidenced. |
| Loading states | 8.1 | Fixed action geometry is an improvement; busy feedback needs more visual presence. |
| Error states | 8.8 | Errors are visible, recoverable and avoid destructive-looking decoration. |
| VoiceOver/labels | 8.0 | Source and label tests are thoughtful, but spoken traversal remains unobserved. |
| iOS HIG consistency | 8.4 | Native components give a strong foundation; login composition feels more assembled than polished. |
| Lock Screen / Live Activity | 8.3 | Captured banner and expanded Island states are readable within a deliberately limited line budget. |
| Sign-in/onboarding | 7.3 | Email-first is a real improvement, but the screen still feels crowded and lacks a clear secondary hierarchy. |
| Settings/account | 8.2 | Native grouping and stronger prefixes help, while expanded explanations remain dense. |
| Performance feel | 8.0 | Available evidence supports functioning transitions, not hardware-level responsiveness. |
| Delight | 7.7 | The app is calm and direct, but polished composition is uneven. |
| Long text | 9.0 | Long-content treatment is strong in the tested board and Account states. |
| Reduced Motion / Transparency | 8.7 | Actual combined settings provide stronger evidence than environment overrides alone. |
| Palette / minimalism | 8.8 | Restrained colors and absence of nested cards fit the requested direction. |

**Visual hierarchy**

Visual evidence: Default empty and filled login originals show the email flow first, but the centered alternate method, divider and outlined provider pair compete; dark empty/loading states emphasize Apple most.

Source assessment: SignInView gives major groups uniform 24-point spacing and makes the alternate method full-width. Board uses a clear title/count, rows and pinned composer.

**Spacing/grid**

Visual evidence: Common left edges are clean. Login fields, action, alternate, divider and providers have a repetitive ladder rhythm; expanded guidance becomes a tall slab.

Source assessment: 20-point form margins and separate 8/20/24-point stacks are predictable. Native Account sections avoid nested cards, though explanatory rows inherit substantial repeated row spacing.

**Typography scale**

Visual evidence: Board body and headers are clear. Notepad branding, Email/Password headings and CTA/link labels compete in XXXL; Home/Lock prefixes improve scanability.

Source assessment: Semantic title2, headline, body and footnote styles are used. Attributed prefix emphasis preserves strings; main alternate authentication action could be visually more subordinate.

**Dynamic Type**

Visual evidence: Long rows, Account instructions and auth helpers wrap without lost final lines in inspected states. Password heading remains visible in full keyboard XXXL captures.

Source assessment: UIKit trait override makes row tests meaningful; fixedSize supports multiline content. Expanded Island explicitly caps at xxxLarge, so this does not establish AX1–AX5 support.

**Light contrast**

Visual evidence: Primary board and Account text are crisp on white/grouped surfaces. Enabled login preview is distinct from deliberately disabled fixtures; loading spinner is visually faint.

Source assessment: Semantic foreground/background choices and Account explanatory-ink tests support contrast. Disabled appearance should not be mistaken for active-text failure; pending spinner needs separate assessment.

**Dark contrast**

Visual evidence: Board text remains clear; the white Apple asset dominates empty/loading login while the small spinner recedes into its gray action.

Source assessment: System colors adapt correctly. Native whiteOutline Apple asset is deliberately retained; any hierarchy fix should change surrounding composition, not redraw the Apple asset.

**Iconography**

Visual evidence: Completion rings, account symbol, keyboard dismiss, warning and widget symbols are recognizable. No decorative red/orange treatment was seen.

Source assessment: SF Symbols and the native Apple button are preserved. Destructive red is semantic; custom six-dot reorder grip is modest, with a larger interaction target.

**Safe area / Dynamic Island**

Visual evidence: No title/account collision with the Island; final board rows clear the footer. Expanded Activity text remains inside the black system shape.

Source assessment: Safe-area insets, native navigation and explicit Activity layout margins support observed results. Only the regular iPhone 17 Pro geometry is established.

**Scroll/pull-down / last row**

Visual evidence: Both themes and sizes retain the final row above the capacity footer after pull/scroll. Some preceding-row glyphs remain faintly visible at the upper edge.

Source assessment: Native UICollectionView refresh and measured final-ink tests address real risks. Custom 24-point gradient top mask explains the residual fade, rather than a missing bottom inset.

**List rows**

Visual evidence: Long paragraphs retain alignment, separation and full text; completion rings align to first lines. Persistent grips add a little visual noise compared with Reminders.

Source assessment: UIHostingConfiguration in native list cells, multiline body text and explicit completion/reorder accessibility actions are sound. Drag behavior is source/test-supported, not hands-on reviewed.

**Empty states**

Visual evidence: All Clear plus bottom composer is legible. The long three-step setup tip occupies more visual attention than the empty-state invitation, especially XXXL.

Source assessment: ContentUnavailableView and dismissible persisted setup guidance are native-minded. Guidance is hidden during composition, which protects the active task.

**Composer ergonomics**

Visual evidence: Typed multiline draft, dismiss key and add action remain visible above the keyboard; capacity state is clearly noneditable.

Source assessment: SafeAreaInset, 1–4-line input, 44-point targets and capacity replacement are appropriate. The tests exercise edge taps and final-row geometry.

**Keyboard handling**

Visual evidence: Actual first-focus and refocus XXXL frames preserve Password heading, field and alternate action. The opaque Done strip cuts off the lower Apple button border; email variants can expose part of Google.

Source assessment: Measured focus frames, idle settlement and keyboardDidShow handling are more robust than guessed offsets. Safe-area Done inset creates a hard visual cutoff below the primary work area.

**Sheet presentation/detents**

Visual evidence: Medium and large detents, grabber, pinned Done and scrolled content are convincing. Long guidance scrolls rather than squeezing.

Source assessment: Native presentationDetents, scroll interaction and insetGrouped List are appropriate. Expanded long guidance still requires substantial traversal at medium size.

**Navigation clarity**

Visual evidence: Board account affordance, Account Done, method-switch actions and inbox confirmation are explicit. Providers remain Apple then Google.

Source assessment: NavigationStack, explicit dismissal and method state changes preserve a simple structure. External and authenticated navigation is not established by inert fixtures.

**Touch targets**

Visual evidence: Completion, add, Done, clear and main login actions have generous apparent targets. Full keyboard captures do not show focused field/action collision.

Source assessment: 44-point minimums, 48-point sign-in Done and provider height, native rows and edge-tap UI tests support the score. No claim of arbitrary-device or motor-accessibility testing.

**Haptics**

Visual evidence: No still image or sampled video can establish tactile strength, timing or duplication.

Source assessment: Success/error sensory feedback and drag selection feedback are present. Physical-device confirmation of add/complete/reorder/auth feedback remains absent; score is provisional.

**Animation/transitions**

Visual evidence: All 16 movies were represented by three actual sampled frames each. Focus and Activity state changes look coherent in those samples; full playback/frame pacing was not reviewed.

Source assessment: Reduced-motion branches and native presentation are sensible. The historical XCTest timeout is not evidence of an app animation hang, nor do passed tests establish smoothness.

**Loading states**

Visual evidence: Filled/loading/baseline triplets retain neighboring positions. Small muted spinner within a large disabled-looking action is less evident than the nearby Apple asset.

Source assessment: Invisible retained title plus overlay spinner preserves layout and accessible progress wording. Geometry/spinner-pixel tests verify stability and existence, not perceived prominence.

**Error states**

Visual evidence: Board empty/populated errors, retry/dismiss, Account refresh failure and sign-in error are legible in both themes and combined settings.

Source assessment: Announcements are deduplicated without forced focus movement. Raw board network-error wording is explicitly retained by user instruction and is not a finding.

**VoiceOver/labels**

Visual evidence: Raster evidence cannot prove reading order, announcements or rotor usability.

Source assessment: Unique Password field label, hidden duplicate heading, progress labels, completion/reorder actions and deduplicated error announcements are appropriate. Spoken VoiceOver sessions remain a gap.

**iOS HIG consistency**

Visual evidence: Account and board resemble native list/sheet idioms. Login combines native Apple, custom Google border, rounded input/action and independent centered link into a busier composition.

Source assessment: NavigationStack, ContentUnavailableView, native collection list and Apple authorization button are appropriate. Custom masks and keyboard inset deserve careful visual review.

**Lock Screen / Live Activity**

Visual evidence: Long text tails truncate and +more counts are clear. Sampled expansion/banner changes do not show collisions; the wallpaper is only one tested background.

Source assessment: Explicit line budgeting and hidden-count handling are coherent, with xxxLarge cap on Island. True locked-device, Always-On, alternate wallpaper and exact Apple Activity references are absent.

**Sign-in/onboarding**

Visual evidence: All 60 same-state pairs were inspected. Empty and filled default originals retain too many competing bands; XXXL password pushes providers/legal into scrolling. The latter is reachable, not a lost-content claim.

Source assessment: Contiguous email/password work area, preserved provider order, isolated fixtures and fixed pending footprint are good. Uniform group spacing and a prominent alternate method leave the central composition unresolved.

**Settings/account**

Visual evidence: Statuses and actions are clear; Home Screen/Lock Screen prefix weight is visible. Expanded instruction rows plus permanent multi-paragraph footer fill much of the sheet.

Source assessment: BoardPersistenceSection changes preserve words and improve prefix hierarchy. DisclosureGroup and insetGrouped List are appropriate; footnote text still needs better subdivision without deleting copy.

**Performance feel**

Visual evidence: Sampled films and settled screenshots show no gross stall; they cannot establish input latency or frame consistency.

Source assessment: Five-sample public launch/scroll metrics are simulator/host/XCTest evidence. Full-suite passes and binary binding support reproducibility; no physical profiling or arbitrary slowdown diagnosis is claimed.

**Delight**

Visual evidence: Readable board and quiet palette are pleasing. Login's repetitive boxes and expanded Account's instruction mass reduce the feeling of a finished native tool.

Source assessment: Simple interactions and restrained feedback create a good base. The remaining opportunity is spacing, emphasis and transitions, not decorative color, new branding or extra cards.

**Long text**

Visual evidence: Full final paragraphs are visible after traversal at XXXL; helpers wrap. Activity truncation is intentional and accompanied by hidden-line counts.

Source assessment: Unbounded row text, fixed vertical sizing and independent ideal-height/ink checks support the board. Long real account identities and localized strings are not demonstrated.

**Reduced Motion / Transparency**

Visual evidence: Combined-setting login and Account/error captures remain readable and stable, including full first-focus/refocus witnesses.

Source assessment: All five methods independently restored four original switches 0/1/0/0. Reduced-motion branches and solid edge-mask fallback exist; full subjective motion comfort is unobserved.

**Palette / minimalism**

Visual evidence: Neutral board and Account surfaces, sparse functional purple and semantic destructive red are consistent. Login's visual density comes from structure rather than decorative colors.

Source assessment: System colors and native asset preservation are appropriate. Continue reducing competing framing/spacing, without changing words, branding, icons or adding red/orange decoration.

## Findings

All proposed changes preserve every existing word, branding, icon and native Apple asset, retain Apple then Google, and avoid nested cards or decorative red/orange. Raw board network-error wording is explicitly **KEEP** and is not reopened.

### R8-ASTRA-01: Email-first ordering has improved the flow, but the composition still has too many competing bands

**Severity:** medium. **Screen:** Sign In: default empty/filled and XXXL password. **Basis:** observed and source-derived. **Confidence:** high.

The page repeats broad field, broad action, centered full-width alternate method, a divider with generous surrounding gaps, two outlined provider controls and a separate legal row. The email action becomes clear when filled, but empty/pending states let the native Apple asset become the strongest object. This is composition and hierarchy, not a request to modify Apple's asset or hide required words.

Evidence:

- [composition-dark-default-default-filled_0_775A7306-3159-4334-83BF-A3B0619AC809.png](native/LoginCompositionUITests/787638D3-71C9-4C7B-82A7-0AED93E1460E.png)
- [composition-dark-default-default-empty_0_FE63E52A-30AD-4DA5-9C5D-51D15C666C2F.png](native/LoginCompositionUITests/B4F5313C-7E8C-400C-8074-55CBC7C0E1F5.png)
- [composition-light-default-password-filled_0_626FE4A2-A82E-46B0-9E42-282486E2DC74.png](native/LoginCompositionUITests/7AB844CA-C9E6-4DDD-87E4-6DA909C858BA.png)
- [composition-light-default-password-empty_0_FDC219AA-C2E5-44B9-9187-5276C370BC80.png](native/LoginCompositionUITests/230381CC-F88F-4937-A9CB-0AE20FDD2DE4.png)
- [composition-light-default-default-filled_0_04C90CCE-88D9-40E3-8842-5877C140C536.png](native/LoginCompositionUITests/77E91E1D-B982-40F5-8AF2-AD0E900D6951.png)
- [composition-light-default-default-empty_0_0900D717-DDA2-4233-962B-4662EA128559.png](native/LoginCompositionUITests/8123BBD3-0830-4980-9D0D-457AE321FD45.png)
- [composition-dark-XXXL-password-filled_0_D8E1A21D-62E7-421B-BD84-6B6E763277AC.png](native/LoginCompositionUITests/2E1050E6-DDAE-42E7-A64A-D64F485CFA12.png)
- [composition-light-XXXL-password-filled_0_7E5DB272-A87B-4F39-BBC2-03FBB32C200A.png](native/LoginCompositionUITests/C913ABC7-7621-421D-8683-3FF306659815.png)

Source: `ios/App/SignInView.swift:67`, `ios/App/SignInView.swift:84`, `ios/App/SignInView.swift:244`.

**Concrete fix:** Keep the contiguous email-first flow. Make the existing alternate-method text a leading-aligned callout within that flow, retaining a minimum 44-point target. Replace uniform large inter-group gaps with explicit field/action and section gaps; start by reducing spacing around the divider from 24 to 16 points while keeping the Apple/Google pair together at its existing order and native Apple styling. Keep legal links in a quieter, reachable footer. Compare complete default empty and filled screens before accepting the change; do not add cards.

**Measurable regression check:** Recapture the same 60 paired states, especially both default empty/filled themes and XXXL password. Assert every original string and native Apple asset/order remain, targets stay >=44 points, default field/CTA/alternate/provider/footer bounds do not overlap, and XXXL legal links remain reachable by a real gesture. Run the existing iOS suite; visual side-by-side review must separately accept the new hierarchy.

### R8-ASTRA-02: The opaque Done strip cuts through a provider control at the settled keyboard boundary

**Severity:** low. **Screen:** Sign In: settled empty-password keyboard, first focus/refocus. **Basis:** observed and source-derived. **Confidence:** high for appearance; medium for proposed layout adjustment.

Actual full-screen first-focus/refocus XXXL witnesses keep Password, input, helper and alternate method clear, which is a successful fix. Below that work area, the Apple button's lower border is cut off by the Done strip; some email captures expose only part of Google. This is a small polish defect at automatic settlement, not proof that the provider is unreachable and not a protected-screenshot artifact.

Evidence:

- [first-focus-combined-dark-XXXL-1](keyboard-video-frames/first-focus-combined-dark-XXXL-1.png)
- [first-focus-combined-dark-XXXL-0](keyboard-video-frames/first-focus-combined-dark-XXXL-0.png)
- [first-focus-combined-light-XXXL-1](keyboard-video-frames/first-focus-combined-light-XXXL-1.png)
- [first-focus-combined-light-XXXL-0](keyboard-video-frames/first-focus-combined-light-XXXL-0.png)
- [first-focus-normal-dark-XXXL-1](keyboard-video-frames/first-focus-normal-dark-XXXL-1.png)
- [first-focus-normal-dark-XXXL-0](keyboard-video-frames/first-focus-normal-dark-XXXL-0.png)
- [first-focus-normal-light-XXXL-1](keyboard-video-frames/first-focus-normal-light-XXXL-1.png)
- [first-focus-normal-light-XXXL-0](keyboard-video-frames/first-focus-normal-light-XXXL-0.png)
- [combined-full-screen-signin-light-XXXL-keyboard_0_8C3CC70A-60FF-4691-BCAE-4955DDAFA5E7.png](native/AccessibilitySettingsUITests/0EFFC803-58F8-48A8-83E6-DAF721F2453B.png)

Source: `ios/App/SignInView.swift:131`, `ios/App/SignInView.swift:219`.

**Concrete fix:** Make the automatic focus settlement respect the boundary after the primary form group as well as the focused heading. When a provider cannot fit wholly above Done, add focused-state separation so that the initial resting viewport ends in the gap before the provider group; keep the complete group in the same scroll view and reachable by user scrolling or keyboard dismissal. Do not shrink the native Apple control or force all controls into the keyboard viewport.

**Measurable regression check:** Use actual unmodified full-screen frames for first focus and refocus, light/dark, default/XXXL, normal/combined settings. Require full heading, field, helper and primary/alternate actions inside the viewport, >=44-point targets, and no provider label or border intersecting the Done strip at automatic settled positions. Exercise manual scroll and Done so providers/legal remain reachable; preserve existing focus/geometry assertions and run the iOS suite.

### R8-ASTRA-03: Stable pending geometry leaves an overly faint busy indicator

**Severity:** low. **Screen:** Sign In: pending email/password action. **Basis:** observed and source-derived. **Confidence:** medium-high.

The new overlay retains the button footprint, but the small muted spinner recedes into a large gray disabled-looking surface while the nearby Apple asset stays visually forceful. The current tests show stable geometry and spinner pixels, not readable progress prominence. No numerical contrast failure is asserted here.

Evidence:

- [loading-stability-dark-XXXL-loading_0_32CE5976-95F4-43E1-B3ED-EADCE0CD2254.png](native/LoginLoadingGeometryUITests/3E2E1D78-5B0F-4294-957B-861358FF8E8F.png)
- [loading-stability-light-XXXL-password-loading_0_7460E018-A556-40ED-9BE8-E8C6E06F33ED.png](native/LoginLoadingGeometryUITests/9901281C-8C8D-43DC-B88D-7B99179176AB.png)

Source: `ios/App/SignInView.swift:509`.

**Concrete fix:** Keep the invisible retained title and fixed footprint, but style the progress indicator explicitly with a stronger semantic foreground that remains visible under the disabled button environment. Keep the existing accessible in-progress wording and do not enlarge surrounding chrome or change copy.

**Measurable regression check:** Retain baseline/loading/baseline y/width/height tolerance checks for both methods, sizes and themes. Add a raster check that the spinner's strongest visible strokes reach at least 3:1 against the measured button fill in both themes, and inspect the whole screen to confirm pending work is apparent. Run the existing iOS suite.

### R8-ASTRA-04: Prefix emphasis helps, but the expanded guidance remains visually dense

**Severity:** low. **Screen:** Account: expanded Add a lasting widget guidance. **Basis:** observed and source-derived. **Confidence:** high.

Home Screen and Lock Screen prefixes now scan better. The two long instruction rows, widget caveat and permanent multi-paragraph footer still read as a continuous instructional block and push the next task far below the fold, especially at XXXL/medium detent. This is density, not clipping or insufficient measured text contrast.

Evidence:

- [dark-XXXL-medium-guidance_0_9BD60A6C-4652-40A9-AF4B-F5CC7F8A66C3.png](native/AccountChromeUITests/F0C4672F-A70D-4B53-888B-A21AD3B7E46D.png)
- [light-default-large-guidance_0_4B208C34-6382-4351-AF29-684BA59AFFD0.png](native/AccountChromeUITests/746699CA-A7B0-412C-BD2D-E1DCBC1830E7.png)
- [dark-XXXL-widget_0_A001DDED-B0EF-41EE-8DFA-0F229D1E88D1.helper](native/AccountDensityUITests/E328EB2C-D2C5-4EDD-90A7-EA20BC7FE7BA.png)
- [light-default-widget_0_EBE90A93-3AB5-4555-B443-DF88D7B4461B.helper](native/AccountDensityUITests/40927732-C4AF-409B-8E75-C820D1735212.png)

Source: `ios/App/BoardPersistenceSection.swift:50`, `ios/App/BoardPersistenceSection.swift:54`, `ios/App/BoardPersistenceSection.swift:68`.

**Concrete fix:** Preserve every string but place each emphasized Home Screen:/Lock Screen: prefix on its own line above its instruction body, with a small internal gap and consistent inter-instruction spacing. Keep the widget caveat visibly subordinate within the disclosure and separate the permanent footer from subsequent action sections using the existing native section structure. Avoid additional card backgrounds.

**Measurable regression check:** Recapture expanded/collapsed Account at both detents, themes and sizes. Require exact original concatenated strings, >=7:1 explanatory-text contrast, first/final-line ink, and existing >=16-point inter-section boundary checks. Verify both instruction prefixes are visually distinct without reducing body size, and all lower actions remain reachable. Run the iOS suite.

### R8-ASTRA-05: Faint preceding-row fragments make the custom upper fade slightly untidy

**Severity:** low. **Screen:** Board: partially scrolled long/full rows, normal and populated error. **Basis:** observed and source-derived. **Confidence:** medium.

Faded text fragments remain directly below the navigation/error boundary after settling. Native Reminders also uses scroll-edge translucency, so this is a modest integration difference, not a general ban on partially visible rows or a safe-area failure. The final row and footer are clear.

Evidence:

- [capacity-dark-XXXL-bottom-after-pull_0_1EE99A30-6C27-4FA6-9969-7BA3F528F407.png](native/BoardCapacityDensityUITests/F0D4E455-FE21-4E39-A867-AB8583431D30.png)
- [capacity-light-XXXL-bottom-after-pull_0_88775972-3FF6-4B75-8C51-EAE7B2C5F15C.png](native/BoardCapacityDensityUITests/FFDFD024-F2A7-44B0-A9E9-F258678BD739.png)
- [populated-error-bottom-true-true_0_8C7B98A2-B193-444D-86E6-90CBE6E6464E.png](native/BoardMultilineUITests/315F5E33-8EB9-4997-83B5-7E2B42707693.png)
- [canonical-long-text-dark-XXXL-bottom-after-pull_0_8C84C40E-A74E-4045-A034-800BB1BFBC83.png](native/HillclimbCaptureUITests/8DDB9F64-FC68-4399-B3CB-02D5B3BB4F13.png)
- [canonical-long-text-light-XXXL-bottom-after-pull_0_F1BFB019-E8DE-479E-83E8-561DF31EE0D1.png](native/HillclimbCaptureUITests/49407B0F-075C-4EF0-9928-EDEA176AE644.png)

Source: `ios/App/ReorderableReminderList.swift:251`, `ios/App/ReorderableReminderList.swift:264`.

**Concrete fix:** Tune the existing custom top mask so its fully transparent strip aligns with the actual native scroll-edge boundary before the transition begins, rather than fading half a glyph immediately beneath a hard boundary. Compare with the matched Reminders top/bottom references; preserve pull refresh, native edge behavior and the solid fallback for accessibility settings.

**Measurable regression check:** Repeat real pull then 83/47/61-point partial drags in both themes/sizes and populated-error states. Extend the existing upper-band raster witness to inspect the mask transition boundary and confirm no isolated crisp glyph fragments appear at the boundary, while the next complete line remains readable. Re-run final-row ink/geometry, refresh settlement and the iOS suite; judge the fade against native references separately.

## Coverage and comparison limits

I inspected **all 28 canonical contact sheets**, covering the **332 canonical paths**, and **47 full-resolution originals** across every main family. Originals include default empty/filled login in both themes, password/email forms, pending/inbox/error states, XXXL empty-password first focus/refocus in normal and combined settings, board top/bottom/capacity/composer/empty/error/loading, Account detents/expanded guidance, and Activity banners/expanded Island. The accompanying [JSON report](scores-gpt-6-astra.json) enumerates all 332 paths relative to this round, all 17 reference paths, all sheet paths and the 47 original paths. The screenshot manifest is not expanded to 522 for repeat-acquisition credit. The 12 unit renders remain separate and receive no native screenshot credit.

I inspected **all 15 login comparison sheets / 60 exact same-state pairs**, and all **17 actual Reminders reference originals**, using [the per-screen pairings](../../validation/round8/reference-pairings.json). These compare native hierarchy, spacing, list/composer and sheet behavior. Reminders also uses scroll-edge translucency; that is why the residual board fade is only a low-severity integration observation. No exact Notes/auth/Activity/capacity/combined-settings comparison is implied.

I inspected **all four video-inspection sheets**, representing **16 actual movies at three sampled frames each (48 total)**, using [the sample manifest](../../validation/round8/video-sample-inspection.json). I did not review full playback or infer frame pacing. Actual keyboard frames supplement protected partial XCTest captures. Original screenshots and recordings were unchanged.

Source review included the board, row hosting/reordering, composer, sign-in, Account, persistence guidance, setup tip, Live Activity/line budgeting, geometry/demo isolation, announcement policies and the relevant focus/loading/Account/board/accessibility UI tests. The complete source list is in the JSON. Tests substantiate geometry and functional state; they do not settle visual taste.

Evidence gaps:

- No Notes references. The 17 actual Reminders originals provide closest native hierarchy/list/composer/sheet comparisons, not exact auth, Activity, capacity or combined-accessibility-settings counterparts.
- Only regular iPhone 17 Pro simulator evidence is established; physical devices, other widths, landscape, Display Zoom and AX1–AX5 are not established.
- Protected XCTest keyboard screenshots are partial. Full keyboard judgments use separately labelled actual movie-derived frames; neither source-only frames nor protected stills establish the complete keyboard composition.
- All 16 movies were inspected through their three actual sampled frames (48 total) in four supplied inspection sheets. This is not full playback, measured frame pacing or input-latency review.
- No physical haptic verification or spoken VoiceOver traversal/rotor session. Those categories rely partly on source and remain provisional.
- No true locked-device, Always-On, arbitrary wallpaper, physical Activity lifecycle, live push delivery or exact native Activity reference.
- Enabled-looking authentication/Account fixtures are inert previews. No live Apple/Google/password/magic-link authentication, production destructive account action or external-link success is demonstrated.
- Five-sample launch/scroll metrics include simulator, host and XCTest overhead. Historical timeout causes are not diagnosed as host load or an app hang.
- New filled loading states lack exact Round 7 counterparts; same-state comparison credit is limited to the recorded 60 pairs.
- Long real account identities and localization expansion are not covered. Activity single-line truncation is intentional; source caps expanded Island type size at xxxLarge.

## Validation and provenance

The supplied [checks manifest](checks.json) reports all required checks passed. I did not run builds, tests or device operations. I independently SHA-256 checked **all 96 frozen inputs (94 tracked + 2 generated)** and **all 332 canonical images** against their manifests: zero missing or mismatched files. The pairing manifest contains 332 distinct screen mappings and all 17 reference paths. The [source binding](../../validation/round8/source-binding.json) distinguishes graded app/tests, production code, capture acquisition revisions and widget reuse.

Recorded validation for `20ae77e29019444a499e9e47c98d6b656ef56819`:

- Unfiltered suite: **325 passed = 263 unit + 62 UI**, zero failures/skips. All **317** baseline named IDs retained, with the recorded 308/307/304/293 transitive baseline coverage.
- Fresh Release build, Python **23**, Deno **52 + 4**, Debug restoration and binary/installed identity checks passed.
- All **five** current Settings methods independently restored the four original switches **0/1/0/0**. The split combined matrix retains all eight cases/assertions and the 240–300-second execution limits.
- Original strings/native branding/Apple asset and the two-file production scope are recorded as preserved.

Exact recorded command arrays, source SHA and proof paths are included in JSON under `validation.supplied_commands`; none are claimed as reviewer-run commands.

Historical failures remain failures:

- Original 322-pass/2-fail suite remains failed: synthetic Password heading estimate did not match the real heading. Test corrected to use the measured heading; later passes do not relabel the failed run.
- Original 323-pass/1-fail suite remains failed: combined eight-case method exceeded 240 seconds with two recorded 60-second XCTest animation-notification waits. No failed layout assertion or diagnosed app hang/host-load cause.
- The timeout bypassed Settings teardown; later methods inherited 1/1/1/1. Explicit recovery restored recorded 0/1/0/0; the current split matrix retains all eight cases/assertions and 240–300-second limits. All five current Settings methods independently restore the originals.
- Nonrequired manual pinned-driver access failed/stopped on stale-owner claim; project runner was used. Earlier movie sampling failures remain historical; usable sampled sheets are explicitly documented.

Five-sample launch/scroll metrics are simulator/host/XCTest evidence, not hardware latency or frame-pacing certification. The review does not infer live authentication from enabled-looking inert fixtures. I read no peer/prior numerical score reports, state.md, REPORT.md, decisions.md or questions.md. No application edits, Git operations, builds or device actions were performed. Only these two review files were written.

Written by gpt-6-astra in Codex on behalf of Edmund

