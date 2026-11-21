# Round 4 independent review — gpt-6-astra

Overall **8.95/10**; minimum **8.2/10**. Source `b5d9bb3df1b20d765ae5efff438190f396827456`. The strongest gains are composer continuity, clear Account disclosure and enabled provider appearance. Remaining work is concentrated in informational contrast and board header clipping; device-only evidence gaps remain explicit. This score is below the final 9.0 overall target and is not adjusted to satisfy an escalation gate.

## Evidence and comparison method

Independent visual/source review. All 288 native screenshots inspected through category contact sheets; 41 selected original-resolution images inspected across families/appearance/default/XXXL. All 17 usable paired Reminders references reviewed through originals and a round3 contact sheet. All seven recordings sampled at six distributed timestamps each. Contact sheets and 12 separate unit renders are not counted as native screenshots. No app/source/test/device/git mutation or new build/test execution by this reviewer.

The native device is the original regular iPhone 17 Pro, iOS 26.2 (23C54), 402×874pt / 1206×2622px, not the Duo simulator. The 288 images comprise core 18, extras 76, board 48, normal post-scroll keyboards 8, enabled sign-in 28, enabled Account 84, Activity 12, motion 4 and actual Settings/accessibility 10. Activity contains eight visible surfaces and four intentionally empty compact/minimal surfaces. The four expanded frames are unmodified native recording extracts.

Each captured state was considered against its closest usable pairing in [pairings.json](pairings.json): ordinary/long boards against Apple top/bottom lists, empty/error boards against empty or list states, composers and keyboard states against Apple compose, and Account against Details. Provider, error, Activity and actual combined-settings states lack exact Apple counterparts. These pairings compare visual hierarchy, typography, navigation edges and surface treatment; they do not imply semantic equivalence. All 17 references are listed below.

Compared with Apple, the plain board and native Account sheet now approach the same quiet hierarchy. The meaningful remaining visible distinction is sharp board content cutting beneath the header, where Apple uses a soft navigation-edge treatment. The app does not need Apple’s colored list title or exact composition to meet this brief.

The supplied validation packet reports 285 actual iOS tests passed (263 unit + 22 UI); fresh Debug/Release, Python 23 and Deno 52+4 passed; all eight normal post-scroll keyboard cases and edge checks passed. Zero observed runtime warnings/invalid frames; 9359 other log events retained, not represented as a clean-log claim. Required programmatic checks passed. Independent reviewer status is optional/informational and cannot be used as its own programmatic gate. I did not infer visual quality, physical performance or spoken accessibility from passing tests.

## Category scores

| Category | Score | Rationale |
|---|---:|---|
| Visual hierarchy | 9.2 | The board title, plain reminder rows and bottom composer form a clear reading order. Account disclosure now has an appropriate body-sized label. Compared with the paired Reminders list and Details sheets, the app is equally restrained, although error blocks are less optically resolved. |
| Spacing/grid | 9.0 | Board gutters and completion/text/reorder columns remain consistent through the 48 board captures. Account destructive-row icon and text alignment is improved. The small sharp remnants immediately under the board header interrupt an otherwise controlled grid. |
| Typography scale | 9.2 | System type creates a convincing title/body/footnote hierarchy in both appearances. The larger Account disclosure label and subordinate guidance read correctly. Long diagnostic text is preserved, but its dense presentation remains less composed than ordinary states. |
| Dynamic Type | 8.9 | Default and ordinary XXXL layouts reflow convincingly across board, sign-in and Account, including expanded guidance and medium detents. Expanded Activity ellipsizes meaningful second-row text at XXXL. AX1–AX5 are unobserved and are not claimed to pass. |
| Light contrast | 8.5 | Primary board text, capacity guidance and corrected sign-in helpers are strong. Native error footnotes use #ff383c on white, measured 3.57:1; loading and empty-board diagnostic text use #8a8a8e on white, 3.44:1. These ordinary-size informational labels fall below the review target of 4.5:1. |
| Dark contrast | 8.9 | Board text, guidance and the native white-outline Apple button are clear in dark originals. Account error red #ff4245 against #2c2c2e measures 4.06:1, below 4.5:1 for the normal-size message. The same red on the darker sign-in background is not the same contrast problem. |
| Iconography | 9.3 | Existing branding is intact; restrained SF Symbols, completion rings and reorder affordances fit the platform. Account delete icon sizing and label alignment are substantially cleaner. Semantic red is confined to error/destructive meaning. |
| Safe area / Dynamic Island | 9.2 | Native captures preserve the status area, title, bottom composer and home indicator. The eight normal keyboard cases and last-row evidence support clearance in those configurations. Four expanded Island frames show appropriate placement; true physical Lock Screen layouts remain unobserved. |
| Scroll/pull-down / last row | 8.4 | The final paragraph and final completion ring remain above the composer after pull and bottom scroll in both appearances and sizes. However, sharp partial lines remain under the board header, unlike the softened navigation-edge treatment in the closest Apple references. Bottom correctness does not resolve this top-edge defect. |
| List rows | 9.3 | Flat text rows, unobtrusive separators and isolated completion rings meet the minimal brief. Source and supplied interaction evidence support a 44pt circle target, paragraph taps preserving completion state and working reorder. This is clearer than making a whole long paragraph a completion action. |
| Empty states | 9.4 | The ordinary empty board is calm, legible and anchored by a clear composer; it uses available space rather than another nested card. The paired Reminders empty screen is a useful hierarchy comparison. Error-empty text contrast is scored under contrast/error states. |
| Composer ergonomics | 9.3 | The composer remains compact and visually connected to the board. Done survives nonempty drafts and retains a 48pt target after reduced padding; draft dismissal/refocus evidence preserves text. Full-board guidance is now unboxed and readable without competing with the main list. |
| Keyboard handling | 9.0 | All eight supplied normal post-scroll sign-in cases show functioning Done and alternate-action clearance. Board nonempty draft dismissal also has direct evidence. Combined actual accessibility-settings evidence is incomplete: a settled still excludes the alternate action, while an earlier recording sample shows it; this is not proof of an unreachable control. |
| Sheet presentation/detents | 9.2 | Account medium/large presentations, expanded guidance and lower actions have consistent native grouping and margins. Default and XXXL captures preserve scrollable content. Apple Details provides a useful material/spacing comparison, with an explicit semantic and medium-detent mismatch. |
| Navigation clarity | 9.3 | The short board-to-Account path, sheet close control and disclosure state are easy to understand. Sign-in alternatives remain visually subordinate to the active method. The captured enabled styles establish appearance, not completion of a real external authentication or account flow. |
| Touch targets | 9.4 | Completion circles, Done, Account controls and sign-in actions have substantial hit areas. The 44pt completion and 48pt Done source geometry aligns with supplied native checks and observed edge interactions. Decorative glyph size is appropriately separated from target size. |
| Haptics | 8.2 | Source uses focused feedback around meaningful actions rather than a visually implied custom effect. The pattern is plausible and restrained, but no physical-device tactile observation establishes strength, timing or duplicate feedback. This is a limited-confidence assessment, not a hardware pass. |
| Animation/transitions | 8.7 | Sampled frames from all seven recordings support coherent draft/guide changes, Account scrolling and Island expansion without an obvious captured layout discontinuity. Reduced-motion handling is present. Sparse temporal sampling cannot establish display cadence, interruption quality or hitch-free animation. |
| Loading states | 8.8 | Existing loading labels and progress indicators make pending work understandable without inventing another visual surface. Both appearance and XXXL states remain composed. The light loading label is unnecessarily faint at 3.44:1; spinner appearance alone does not substitute for readable status text. |
| Error states | 8.5 | Populated board errors now reuse the existing heading and Try Again action while keeping the full diagnostic string. Account recovery/reappearance and sign-in errors are represented. Dense raw diagnostics and weak light/error contrast still reduce polish; wording changes are not authorized, so improve hierarchy/ink while preserving exact strings. |
| VoiceOver/labels | 8.6 | Explicit controls, loading labels and separate exact-once error announcement policies are present. Source leaves full reminder text on the completion button and on a separate contained Text, with another full-text reorder label: potential repetitive paragraph traversal needs a focused spoken audit. No spoken VoiceOver or complete traversal was observed. |
| iOS HIG consistency | 9.2 | Native typography, sheets, provider treatment, keyboard controls and quiet grouped Account settings create a convincing iOS surface. The app does not need to duplicate Reminders composition. Sharp top clipping and informational error contrast are the notable departures from the reference level of finish. |
| Lock Screen / Live Activity | 8.6 | Eight visible native Activity captures and four intentionally empty compact/minimal captures faithfully show the chosen surface policy. Overflow counts track the displayed row budget and styling is restrained. Meaningful text truncation at XXXL limits utility; physical locked-screen/wallpaper behavior is unverified and Notification Center is not mislabeled as that evidence. |
| Sign-in/onboarding | 9.0 | The provider stack, native dark Apple outline, email/password alternatives and corrected helpers are readable and well ordered in default/XXXL. Enabled-style fixtures remove the misleading disabled appearance for review. Error text contrast remains weak, and inert fixtures cannot certify real provider success or failure journeys. |
| Settings/account | 9.0 | Account now has a clear disclosure label, subordinate readable guidance, aligned destructive row and legible footers. Medium/large and expanded/recovered states hold together in both appearances. The long top error remains visually dense and its red text is below the contrast target in both appearances. |
| Performance feel | 8.2 | Captured states and sampled transitions show no obvious hang, and the validation packet reports zero observed runtime warnings or invalid-frame events. Neither passing tests nor encoded video fps measures launch latency, frame pacing or physical scroll responsiveness. Performance feel remains provisionally good with limited direct evidence. |
| Delight | 8.8 | The best quality is restraint: immediate text capture, plain readable reminders and simple Account disclosure make the app feel lightweight. The preserved icon/branding provide identity. The remaining clipping and crowded diagnostics prevent an entirely effortless finish. |
| Long text | 9.0 | Board paragraphs wrap without horizontal clipping; final ink survives scroll/pull and the composer. Account guidance and raw errors remain fully available through scrolling, preserving wording. Expanded Island single-line rows discard some distinguishing words at XXXL; that constrained-surface tradeoff needs refinement. |
| Reduced Motion / Transparency | 8.7 | Selected native screenshots prove actual Reduce Motion, Reduce Transparency and Increase Contrast enabled together, and proof restores all three Off. Source supports adaptive material/transition choices. The selected configuration looks coherent, but there is no complete combined-settings keyboard matrix or observed AX1–AX5 coverage. |
| Palette / minimalism | 9.6 | The monochrome board, flat rows and restrained native sheet groups closely fit the requested Apple-native/Cursor-like taste. No nested decorative cards or red/orange decoration are introduced. Existing semantic error/destructive red and original branding remain intact. |

Arithmetic: 268.4 ÷ 30 = 8.946667, rounded to **8.95**.

## Findings

P2 is a material readability issue; P3 is localized polish or a targeted verification task. No finding authorizes wording, branding or icon changes.

| ID / severity | Screen and evidence | Finding and basis | Concrete copy-preserving action | Confidence / regression requirement |
|---|---|---|---|---|
| R4A1 / P2 | Sign In errors, Account errors, board loading and empty-board errors<br>[signin-enabled/signin-light-default-error.png](signin-enabled/signin-light-default-error.png)<br>[signin-enabled/signin-light-XXXL-error.png](signin-enabled/signin-light-XXXL-error.png)<br>[account-enabled/screens/error-light-default-initial.png](account-enabled/screens/error-light-default-initial.png)<br>[account-enabled/screens/error-dark-default-initial.png](account-enabled/screens/error-dark-default-initial.png)<br>[extras/board-loading-light-default.png](extras/board-loading-light-default.png)<br>[extras/board-error-empty-light-default.png](extras/board-error-empty-light-default.png) | **Informational error and loading text misses the contrast target.** Opaque light error ink #ff383c on #ffffff is 3.56966:1. Dark Account error ink #ff4245 on its #2c2c2e surface is 4.05969:1. Light loading and empty-board diagnostic ink #8a8a8e on white is 3.43888:1. These are informative labels at ordinary text sizes; disabled controls and decorative shapes are excluded.<br>Basis: observed native pixels, supported by source. Source: `ios/App/SignInView.swift:86`, `ios/App/AccountView.swift:31`, `ios/App/ReminderListView.swift:57`, `ios/App/ReminderListView.swift:180` | Keep every existing string verbatim. Give informational error/loading/diagnostic text primary adaptive ink, retaining semantic red in an existing warning icon, or choose a verified adaptive semantic error text shade. Keep headings and retry actions distinct without introducing cards or new wording. | high. Add native raster checks for informative labels in light/dark default/XXXL and increased-contrast states using solid glyph/background pixels, requiring >=4.5:1 at ordinary sizes; preserve exact-copy assertions and rerun the existing iOS suite. Current read-only reviewer pixel measurement ran; the proposed regression has not been implemented or run. |
| R4A2 / P3 | Long/full board after bottom scroll and pull<br>[full-light-default-bottom-after-pull.png](full-light-default-bottom-after-pull.png)<br>[full-dark-default-bottom-after-pull.png](full-dark-default-bottom-after-pull.png)<br>[long-text-light-XXXL-bottom-after-pull.png](long-text-light-XXXL-bottom-after-pull.png)<br>[long-text-dark-XXXL-bottom-after-pull.png](long-text-dark-XXXL-bottom-after-pull.png) | **Sharp preceding-row fragments remain below the board header.** Partial line fragments have a hard horizontal cutoff immediately under the header. The corresponding Apple list references soften the moving content at the navigation edge. This finding is independent of the passing last-row geometry and ink checks.<br>Basis: observed; source confirms a soft-edge request that does not fully resolve the result. Source: `ios/App/ReorderableReminderList.swift:48` | Correct the native list/header edge integration so content exits under a consistent soft or opaque navigation boundary. Preserve all reminder text, the flat row layout and bottom composer clearance; do not reintroduce a fade over the final visible row. | high. Capture controlled scroll offsets around header crossings in both appearances/default/XXXL; compare top-edge ink continuity and inspect native originals. Rerun the existing last-row ink/geometry and 44pt interaction checks plus the iOS suite. Current evidence demonstrates the unresolved edge; no new regression was run. |
| R4A3 / P3 | Expanded Dynamic Island with multiline reminders<br>[activity/multiline-dark-XXXL-expanded.png](activity/multiline-dark-XXXL-expanded.png)<br>[activity/multiline-light-XXXL-expanded.png](activity/multiline-light-XXXL-expanded.png) | **Expanded Activity loses distinguishing words at XXXL.** The second visible reminder ends in an ellipsis before all distinguishing words are available. Displayed-row overflow counts remain consistent, so this is information density rather than an incorrect count. Unlimited text cannot fit the Island; the opportunity is a better budget for the first useful reminders.<br>Basis: observed truncation, supported by single-line row policy in source. Source: `ios/Widget/ReminderLiveActivity.swift`, `ios/Shared/LockScreenLineBudget.swift` | Evaluate a two-line allowance for a long visible reminder with the shared height/row budget recalculated, accepting fewer visible reminders when necessary. Preserve original strings and accurate overflow counts, and expose the complete reminder to accessibility. Adopt it only if native captures show better usable information without clipping. | high for truncation; medium for the preferred layout tradeoff. Add worst-case long-word/multiline native captures at default/XXXL in both appearances, assert visible glyphs stay within the expanded surface and overflow counts match hidden reminders, and rerun Activity budget tests plus the iOS suite. This alternative has not been implemented or validated. |
| R4A4 / P3 | Board paragraph rows and reorder affordance<br>[long-text-light-XXXL-bottom-after-pull.png](long-text-light-XXXL-bottom-after-pull.png) | **Long reminder text may repeat during VoiceOver traversal.** The completion button has the entire reminder as its label, the visible Text is a separate child of a contained row, and reorder also includes the entire reminder. This may make a long paragraph unnecessarily repetitive; source alone cannot establish the exact spoken sequence.<br>Basis: source-derived risk; spoken behavior unobserved. Source: `ios/App/ReminderListView.swift:647`, `ios/App/ReminderListView.swift:662`, `ios/App/ReorderableReminderList.swift:118` | First inspect the native accessibility hierarchy and spoken traversal. If the static text duplicates the completion label, hide that redundant static accessibility element or provide a deliberately grouped row with distinct complete/reorder actions. Preserve the full reminder, labels, status and ability to review text without completing it. | medium. Add a native accessibility-tree assertion for a paragraph row that preserves complete/reorder actions and full text without a duplicate static-text stop, then perform spoken VoiceOver traversal and rerun the iOS suite. Do not treat a source assertion as a spoken pass. |
| R4A5 / P3 verification | Sign In, light XXXL, actual Reduce Motion/Transparency/Increase Contrast On<br>[accessibility/signin-light-XXXL-all-three-settled.png](accessibility/signin-light-XXXL-all-three-settled.png)<br>[accessibility/selected-states-all-three-enabled.mp4](accessibility/selected-states-all-three-enabled.mp4) | **Combined accessibility-settings keyboard coverage remains incomplete.** The settled still includes Done but places the alternate action outside the viewport. A sampled frame near 7.70s shows Use an Existing Password above Done, and a later sample shows AutoFill. The evidence cannot support an unreachability diagnosis or a complete combined-settings keyboard pass.<br>Basis: observed viewport difference; no established product defect. Source: `ios/App/SignInView.swift` | Run a focused native keyboard/focus/scroll/edge-tap matrix under the three settings individually and together, retaining existing wording and normal behavior. Change scroll-to-focus/inset handling only if this reproduces an obstructed or unreachable action. | high that evidence is incomplete; low that the alternate action is unreachable. Extend the existing eight normal post-scroll keyboard scenarios to actual system settings, record keyboard/Done/alternate-action frames and successful edge taps, and rerun the iOS suite if a fix is required. No such full matrix is present; all eight normal-settings cases remain accepted as passed. |

Read-only pixel measurement: Read-only Pillow pixel counts from native original screenshots; compute sRGB relative luminance using c/12.92 below 0.04045, otherwise ((c+0.055)/1.055)^2.4, weighted 0.2126/0.7152/0.0722; contrast=(Llighter+0.05)/(Ldarker+0.05). Opaque recurring foreground and adjacent solid background pixels selected; antialiased edges excluded. No test suite was rerun by reviewer. Light Sign In error contains 8,557 solid #ff383c pixels; the XXXL counterpart contains 22,422. Light Account error contains 12,138 such pixels. Dark Account error region contains 10,815 solid #ff4245 foreground pixels against #2c2c2e. Light loading and empty-board diagnostic regions contain 3,292 and 9,021 solid #8a8a8e pixels respectively. These measurements concern useful ordinary text, not disabled provider fixtures, placeholders or decorative shapes.

## Round 3 dispositions

| Earlier issue | Disposition | Evidence / limitation |
|---|---|---|
| R3A1: nonempty composer loses Done | resolved in captured scope | Done is tied to focus, remains available with a nonempty draft and preserves draft text through dismissal/refocus; 48pt target retained after 8pt padding reduction. |
| R3A2: capacity guidance and sign-in helper contrast | resolved in captured scope | Capacity guidance now uses strong primary ink without a nested box; sign-in helpers pass supplied >=4.5 measurements. R4A1 concerns separate error/loading labels, not reopening those corrected helpers. |
| R3A3: Account error announcements | source policy and state coverage resolved; spoken verification open | Independent error/result policies announce a new message once, reset after nil and allow reappearance. Supplied recovery/reappearance states support state coverage; speech was not heard. |
| R3A4: populated-board error hierarchy/retry | hierarchy and recovery resolved; wording limitation remains | Existing error heading and Try Again are reused with full raw diagnostic text preserved. Replacement wording is a pending user decision, not an authorized implementation request. |
| Dark Apple provider appearance and enabled styles | resolved visually | Native white-outline Apple button is legible in dark mode; inert enabled-style fixtures expose normal provider appearance without claiming live auth. |
| Account disclosure type, delete alignment and footers | resolved visually in supplied matrix | Body-sized disclosure label, subordinate footnote children, 24pt icon/14pt gap alignment and readable footer ink are visible at default/XXXL. |
| Circle-only completion and reorder | resolved in supplied native scope | 44pt completion target is separate from paragraph text; supplied paragraph-tap, completion and reorder checks pass. |
| Top-edge board fragments | unresolved | R4A2 remains visible despite the UIKit soft top-edge flag. Final-row ink/geometry passes do not cover this region. |
| Reduced settings evidence | improved but incomplete | Actual system-setting proof and restoration Off are present; selected combined states do not complete every keyboard or accessibility-size scenario. |

## Evidence gaps

- No usable Apple Notes reference, exact sign-in/authentication reference, Activity reference, or exact error/loading counterpart; comparisons use the closest usable Reminders state without claiming functional equivalence.
- Account is semantically different from Apple reminder Details; exact medium-detent counterparts are absent.
- XXXL is extraExtraExtraLarge. AX1–AX5 layouts and a full accessibility-size keyboard matrix remain unobserved.
- Spoken VoiceOver output, traversal order and physical-device haptics were not observed. Source policies and native hierarchy tests do not substitute for those observations.
- No true physical locked-screen/wallpaper evidence. Notification Center and expanded Dynamic Island evidence are labeled as such; compact/minimal surfaces are intentionally empty.
- No physical launch latency, display refresh/frame-pacing or interaction-performance measurements. Encoded fps and sampled video frames do not establish smoothness or performance.
- Actual combined accessibility settings were captured only in selected states. The settled sign-in alternate-action viewport differs from an earlier recorded frame; a full keyboard reachability pass is not established.
- Enabled sign-in fixtures are inert with callback guards; Account fixtures allow local disclosure/synthetic recovery but guard real external actions. They establish appearance/local behavior, not live authentication, destructive account actions or external recovery.
- Raw diagnostic wording is preserved. A product wording question remains pending; this review does not approve replacement copy.
- All seven recordings were inspected through six distributed timestamp samples each, not a frame-by-frame or real-time performance audit. Static/native source and supplied validation are the main evidence.

## Evidence manifest

The JSON companion contains all 288 native screenshot paths, all 27 contact sheets, the 41 original-resolution samples, seven recordings and 17 references. Paths are relative to this round directory. All listed paths were checked for existence. Original-resolution samples:

- [full-light-default-bottom-after-pull.png](full-light-default-bottom-after-pull.png)
- [full-dark-default-bottom-after-pull.png](full-dark-default-bottom-after-pull.png)
- [long-text-light-XXXL-bottom-after-pull.png](long-text-light-XXXL-bottom-after-pull.png)
- [long-text-dark-XXXL-bottom-after-pull.png](long-text-dark-XXXL-bottom-after-pull.png)
- [board/light-XXXL-nonempty-focused.png](board/light-XXXL-nonempty-focused.png)
- [board/dark-default-nonempty-dismissed.png](board/dark-default-nonempty-dismissed.png)
- [extras/board-error-populated-light-XXXL.png](extras/board-error-populated-light-XXXL.png)
- [extras/board-error-empty-dark-default.png](extras/board-error-empty-dark-default.png)
- [signin-enabled/signin-light-XXXL-error.png](signin-enabled/signin-light-XXXL-error.png)
- [signin-enabled/signin-dark-default-default.png](signin-enabled/signin-dark-default-default.png)
- [signin-enabled/signin-dark-XXXL-password.png](signin-enabled/signin-dark-XXXL-password.png)
- [signin-enabled/signin-light-default-inbox.png](signin-enabled/signin-light-default-inbox.png)
- [account-enabled/screens/normal-light-default-large-top.png](account-enabled/screens/normal-light-default-large-top.png)
- [account-enabled/screens/normal-dark-default-expanded-lower.png](account-enabled/screens/normal-dark-default-expanded-lower.png)
- [account-enabled/screens/normal-light-XXXL-expanded-guidance.png](account-enabled/screens/normal-light-XXXL-expanded-guidance.png)
- [account-enabled/screens/normal-dark-XXXL-expanded-top.png](account-enabled/screens/normal-dark-XXXL-expanded-top.png)
- [account-enabled/screens/error-light-default-initial.png](account-enabled/screens/error-light-default-initial.png)
- [account-enabled/screens/refresh-error-dark-XXXL-reappeared.png](account-enabled/screens/refresh-error-dark-XXXL-reappeared.png)
- [keyboards/signin-light-default-keyboard.png](keyboards/signin-light-default-keyboard.png)
- [keyboards/signin-dark-default-password-keyboard.png](keyboards/signin-dark-default-password-keyboard.png)
- [keyboards/signin-light-XXXL-password-keyboard.png](keyboards/signin-light-XXXL-password-keyboard.png)
- [keyboards/signin-dark-XXXL-keyboard.png](keyboards/signin-dark-XXXL-keyboard.png)
- [accessibility/signin-light-XXXL-all-three-settled.png](accessibility/signin-light-XXXL-all-three-settled.png)
- [accessibility/account-dark-XXXL-all-three-enabled.png](accessibility/account-dark-XXXL-all-three-enabled.png)
- [activity/multiline-dark-XXXL-expanded.png](activity/multiline-dark-XXXL-expanded.png)
- [activity/multiline-light-default-expanded.png](activity/multiline-light-default-expanded.png)
- [activity/multiline-light-XXXL-notification-center.png](activity/multiline-light-XXXL-notification-center.png)
- [activity/multiline-dark-default-notification-center.png](activity/multiline-dark-default-notification-center.png)
- [motion/composer-light-default-refocused.png](motion/composer-light-default-refocused.png)
- [motion/account-dark-XXXL-lower.png](motion/account-dark-XXXL-lower.png)
- [extras/board-loading-light-default.png](extras/board-loading-light-default.png)
- [extras/board-loading-dark-XXXL.png](extras/board-loading-dark-XXXL.png)
- [extras/guide-light-XXXL-restored.png](extras/guide-light-XXXL-restored.png)
- [board/dark-XXXL-completion-after.png](board/dark-XXXL-completion-after.png)
- [account-enabled/screens/detents-light-XXXL-expanded-medium-lower.png](account-enabled/screens/detents-light-XXXL-expanded-medium-lower.png)
- [account-enabled/screens/error-dark-XXXL-medium-reappeared.png](account-enabled/screens/error-dark-XXXL-medium-reappeared.png)
- [extras/board-error-empty-light-default.png](extras/board-error-empty-light-default.png)
- [signin-enabled/signin-dark-default-error.png](signin-enabled/signin-dark-default-error.png)
- [account-enabled/screens/error-dark-default-initial.png](account-enabled/screens/error-dark-default-initial.png)
- [accessibility/settings-motion-confirmed-enabled.png](accessibility/settings-motion-confirmed-enabled.png)
- [accessibility/settings-display-enabled.png](accessibility/settings-display-enabled.png)

Paired usable references:

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

Recordings sampled (encoded fps is not a display-performance metric):

- [accessibility/selected-states-all-three-enabled.mp4](accessibility/selected-states-all-three-enabled.mp4)
- [activity/multiline-dark-XXXL-expanded.mp4](activity/multiline-dark-XXXL-expanded.mp4)
- [activity/multiline-dark-default-expanded.mp4](activity/multiline-dark-default-expanded.mp4)
- [activity/multiline-light-XXXL-expanded.mp4](activity/multiline-light-XXXL-expanded.mp4)
- [activity/multiline-light-default-expanded.mp4](activity/multiline-light-default-expanded.mp4)
- [motion/account-dark-XXXL-scroll.mp4](motion/account-dark-XXXL-scroll.mp4)
- [motion/composer-light-default.mp4](motion/composer-light-default.mp4)

Written by gpt-6-astra in Codex on behalf of Edmund
