# Round 6 independent UI/UX review

**Overall 8.83/10; minimum category 7.8 (Settings/account).** Arithmetic mean of the 30 scores below. The overall ≥9 stop gate is not met. This is a review-only assessment of graded source `b846a9155dd4b1dd773482f6cc4169a73441ba25`; no code, build, tests or device state was changed by this reviewer.

Edmund's “looks croweded as fuck” concern remains actionable. Account is the clearest normal-content example; sign-in needs better field grouping; the full-board footer repeats guidance. Safe geometry, readable contrast and passing tests do not establish visual calm or replace Edmund's acceptance.

## Evidence and acquisition

I inspected **all 51 core family contact sheets covering all 537 historical native PNGs**, all **20 supplemental originals individually**, both reference contact sheets covering **17 usable Apple references**, 54 selected historical originals at full resolution, and eight selected Apple originals at full resolution. The JSON manifest lists all 557 screenshots, all 17 references and every inspected sheet/original. No supplemental sheet was present; those 20 were inspected directly.

Full-resolution sampling covers light/dark and default/XXXL board fresh top, after-pull true bottom, local completion and focused composer; Account large/medium, scrolled/expanded guidance and recovery; sign-in enabled/default/loading/error/inbox, legal, populated password and normal/combined keyboards; board empty/guide/error/loading; native Activity expanded/banner and long text. All other captured families, including capacity before/after, accessibility combinations and edge states, were covered through the 51 sheets. Protected XCTest password screenshots are partial; separate full-device populated and combined-keyboard originals complete that visual evidence.

Nine recordings were reviewed through three distributed samples each, using [sample sheet 1](../../validation/round6/video-inspection-1.jpg), [2](../../validation/round6/video-inspection-2.jpg) and [3](../../validation/round6/video-inspection-3.jpg). These 27 samples do not establish continuous smoothness.

The 537 historical images retain actual acquisition SHA **6333a32734fffab457e100777f3515de831effae** and their original binary identity. They are not relabelled as b846 captures. The 20 native supplements are separately inventoried at the graded revision in [native-inventory.json](../../validation/round6/recheck/native-inventory.json). [Provenance](../../validation/round6/recheck/provenance.json) establishes all 54 production files byte-identical across historical/current sources; the added tests supply actual gesture proof. Parent independently verified the 537 original, 20 supplemental, 17 reference and 54 production hashes; I did not repeat that full hash audit.

Some original-checkout iCloud/Git metadata reads stalled. Remaining review used the parent-verified frozen copy at `/Users/limboenedmund/.t3/worktrees/lazy-mans-reminders/t3-96aab48e/`. All report paths refer to the original packet. Missing bytes were not treated as visual findings. Structured checks/provenance/acceptance/restoration records were reviewed; full raw diagnostic logs were not exhaustively read.

## Priority density audit

### 1. Account: normal copy creates a real hierarchy problem

**Medium severity · high confidence · observed and source-derived.** See [default large](account-enabled/screens/normal-light-default-large-top.png), [dark XXXL large](account-enabled/screens/normal-dark-XXXL-large-top.png), [expanded XXXL guidance](account-enabled/screens/normal-light-XXXL-expanded-guidance.png) and [XXXL medium](account-enabled/screens/detents-light-XXXL-normal-medium-top.png).

At default size the Keep Your Board Visible group already mixes two read-only statuses with Refresh, Open Settings and the widget disclosure. The two full guidance paragraphs follow all those actions in primary ink. At XXXL the status wraps, the exact footer becomes a large block, and expanded widget guidance introduces three additional paragraphs and separators. There is no synthetic long reminder text here: this density comes from normal layout, information order and repeated instructional prominence. The lower legal/export/feedback/destructive groups are individually understandable and neutrally styled; they do not need extra card containers.

Paired [Apple default Details](../../reference/round2/reminders-sheet-light.png) and [dark XXXL Details](../../reference/round3/reminders-sheet-dark-XXXL.png) make local purpose clearer through labeled sections and separation between different tasks. Their content is much shorter and semantically different, so their viewport height is not a valid target for this Account screen. The useful comparison is the association of explanation with the item it explains. Current 6pt paragraph spacing, hard native top edge and safe Done control are real improvements; they do not resolve that association.

**Concrete next task and ownership:** [BoardPersistenceSection.swift](../../../ios/App/BoardPersistenceSection.swift) should place each unchanged activity/background paragraph immediately beneath its owning status as a visible contextual footnote. Put Refresh/Open Settings/widget actions after a distinct native section boundary. [AccountView.swift](../../../ios/App/AccountView.swift) owns the surrounding section rhythm: distinguish 6–8pt helper spacing from a 16–24pt status/action boundary instead of uniformly compact sections. Retain both exact paragraphs, expanded guidance, recovery copy and all actions. Keep existing type sizes. Consider semantic secondary help ink only after ≥4.5:1 contrast checks in light/dark/combined settings. No nested cards or added disclosure that hides this information. A screen need not fit into one viewport to be calm.

**Regression/acceptance:** assert both paragraphs once, verbatim and adjacent to their owner before unrelated actions; measure those local/group gaps; capture large/medium/expanded/error/recovery in all four appearance/size variants. Preserve ≥44pt targets, medium Done ≥44pt, native hard edge, complete scroll reachability and actual Settings restoration. Run the existing iOS suite. Compare before/after visually with Edmund; no frame assertion can certify calm.

### 2. Sign-in: improve the relationships inside the form

**Medium severity · high confidence · observed and source-derived.** See [default](signin-enabled/signin-light-default-default.png), [dark XXXL](signin-enabled/signin-dark-XXXL-default.png), [populated XXXL keyboard](signin-chrome-manual/final-native-normal-light-XXXL-focused.png), [combined keyboard bottom](signin-chrome-manual/final-native-combined-dark-default-bottom.png), and supplemental ordinary [initial](../../validation/round6/recheck/manual-native/light-XXXL-initial.png)/[bottom](../../validation/round6/recheck/manual-native/light-XXXL-bottom.png).

Default sign-in has ample overall space. Its issue is local grouping: SignInSection uses the same 12pt child spacing for label, helper, field, Password label, field, helper, submit and alternate method. Helpers in primary ink compete with labels. Populated XXXL turns this into a tall sequence of provider rectangles, fields, actions and explanatory lines; increasing every gap would only make it longer. The persistent Password label and 48pt field are correct and should stay.

Paired [Apple XXXL composer](../../reference/round3/reminders-compose-light-XXXL.png) and [default Details](../../reference/round2/reminders-sheet-light.png) show stronger local label/input association. Neither is an authentication screen; no exact Apple sign-in or combined-keyboard reference exists. Preserve all legitimate methods and legal wording.

**Concrete next task and ownership:** in [SignInView.swift](../../../ios/App/SignInView.swift), form unpainted field units with label/helper/field 6–8pt apart, Email/Password units 16–20pt apart, and a distinct 24pt provider/email boundary. Retain typography, every word, provider option, branding/icon, raw network error, password field, submit/alternate/Done/legal targets and the single shared legalFooter. Validate any subordinate semantic helper ink. Add no card backgrounds and hide no methods.

**Regression/acceptance:** check exact wording and label persistence at populated password; capture default/password/loading/error/inbox and normal/combined keyboards across the four variants. Retain 48pt password/Done and ≥44pt legal/action targets, hard native edge and keyboard clearance. Repeat the ordinary actual-pan method and preserve at least current 50pt XXXL legal-bottom clearance, plus separate enabled-paint geometry/inertness checks and the existing iOS suite. Ask Edmund to compare the grouping.

The historical failed pan used a deliberately noninteractive appearance root (`allowsHitTesting(false)`). It remains `contract_invalid`, required false, and is **not a production scrolling bug**. The new required ordinary method starts at the natural top, performs real drags in all four variants, and proves 127pt movement at XXXL with 50.333pt bottom clearance. Default moves 52pt through native title collapse and already fits. Separate enabled-paint dimensions and inertness pass; absolute Y and color are explicitly not equivalent to the disabled ordinary fixture.

### 3. Board/composer: distinguish repeated chrome from stress content

**Low severity · high confidence · observed and source-derived.** See [default true bottom](board/light-default-true-bottom-after-pull.png), [dark XXXL true bottom](board/dark-XXXL-true-bottom-after-pull.png) and [XXXL local completion](board/light-XXXL-completion-after.png).

The board's largest walls of text are seeded repeated long paragraphs. Apple's [XXXL board](../../reference/round3/reminders-top-light-XXXL.png) uses shorter, varied reminders; judging the row layout by raw screenshot density would confound content with design. The app also reserves completion and reorder columns, which reduce the text measure; those are usable controls, not proof that typography should shrink. Equal natural-length fixtures are needed before changing row gutters.

The independent layout issue is at capacity. A long Hint asks users to combine reminders, followed by the body-sized “Board full — combine lines instead” status with a different leading gutter (approximately 18pt versus 30pt from source). They read as two instructions about the same task. At XXXL this repeated footer weighs against already tall rows.

**Concrete next task and ownership:** [ReminderListView.composer](../../../ios/App/ReminderListView.swift) should put the unchanged capacity status first and its exact Hint immediately below, with one leading gutter and 6–8pt local separation. Rebalance existing padding so the footer does not grow. Retain full-width body-size status/static semantics and no Add at capacity. Keep all wording. [ReorderableReminderList.swift](../../../ios/App/ReorderableReminderList.swift) owns the row gutter/grip reservation; assess matched natural content before changing it.

**Regression/acceptance:** all four variants must retain exact status/Hint once, leading x within 1pt, no status truncation, no Add at capacity, unchanged font and footer height no greater than baseline. Repeat true-bottom/after-pull clearance and capacity→local completion→ordinary composer/draft Done tests, ≥44pt controls and the existing iOS suite. Add matched natural-content comparisons against Apple.

Ordinary composer states compare well with [Apple XXXL compose](../../reference/round3/reminders-compose-light-XXXL.png) and [dark compose](../../reference/round2/reminders-compose-dark.png): entry, Done/Add and keyboard separation remain usable. Local completion only through its circle, inert text taps, draft preservation and full last-row clearance are supported. The custom 24pt top mask/6pt opaque accessibility boundary is unchanged; it is not Apple's native blur.

## Other Apple comparisons and retained limits

Apple's empty state is more minimal than the app's All Clear plus setup guidance. The app's guidance remains dismissible and disappears on focus; at XXXL it is more instructional, but the reviewed originals do not establish clipping. Loading/error states retain context and useful recovery. The exact raw network error is deliberately retained; removing or rewriting it is outside this review's recommendations.

Account's native large/medium detents, hard top edge and local 46pt Done are materially closer to the paired native Details behavior. Q preserves the two exact guidance paragraphs with 6pt separation; O preserves populated Password labeling/48pt field and a hard native edge; N preserves full-width body-size capacity status and removes Add at capacity. These are correctness gains, not evidence that density is accepted. Rejected M remains unchanged.

Native Activity expanded and banner images support the line budgets and hidden-count presentation. P now uses native tightening so **both short XXXL Island rows are complete**, with two visible/eight hidden; default is three/seven. Banner short cases are five/five default and four/six XXXL. The long fixture still tail-truncates: Island three/five default and two/six XXXL; banner five/three and four/four. Do not generalize the short-row improvement to arbitrary long text. Compact/minimal are EmptyView. Notes and exact Apple equivalents for these Activity, authentication, capacity and Account guidance states are unavailable; [pairings.json](pairings.json) records semantic, size and configuration gaps. References guide hierarchy and native behavior, not copied layouts.

Source review included SwiftUI/UIKit board/list/row geometry, SignIn/LMRChrome, Account/BoardPersistence/settings paths, Activity/line budgets and relevant geometry, gesture, capacity, account, settings and performance tests. Labels/row movement actions and reduced-motion/transparency fallbacks are source-supported. Physical haptics, spoken VoiceOver, actual physical Lock/wallpapers, accessibility sizes 1–5, live auth and AutoFill remain unobserved.

## Validation and performance scope

The accepted frozen recheck is **308/308 (263 unit +45 UI), zero failures/skips**, retaining all 307 historical, 304 pre-performance and 293 round-5 named IDs. All three Settings-changing methods independently restore all four original values (Reduce Motion 0, Auto-Play Message Effects 1, Reduce Transparency 0, Increase Contrast 0) at each teardown. Fresh unsigned arm64 Debug build-for-testing and the serial full suite passed. Historical Release/Python 23/Deno 52+4 are explicitly reused only with matching production/backend/pins; I did not execute them.

The exact command/result/SHA are retained in [combined-process.json](../../validation/round6/recheck/combined-process.json), [acceptance](../../validation/round6/recheck/test-acceptance.json), [restoration](../../validation/round6/recheck/combined-restoration-proof.json), [checks](../../validation/round6/recheck/checks.json) and the accompanying score JSON. It used the generated b846 xctestrun, original regular iPhone 17 Pro simulator `78F5A64F-7B2E-4562-8EF9-10F3312CC694`, serial test-without-building and 240/300s allowances; exit 0. Actual runtime is iOS26.2/23C54 despite SDK27.1 filenames. The earlier incorrect 120/180s attempt timed out/interrupted (exit75) and required manual setting restoration before the corrected run. It is retained, not counted as acceptance. The passing normal-keyboard method's **1389.957s** runner duration is unexplained and is not responsiveness proof.

[Public performance samples](../../validation/round6/recheck/performance-results.json), five each:

| Metric | Mean seconds | Standard deviation seconds |
|---|---:|---:|
| Launch | 1.034554 | 0.031416 |
| Clock scroll | 4.683453 | 0.174772 |
| Public scroll signpost duration | 2.347129 | 0.014033 |

These are simulator Debug baseline durations, with XCTest dispatch/quiescence and coarse full-suite host load, not per-sample isolated load. They measure no frame pacing/hitches, hardware feel or before/after benefit. RuntimeWarnings is empty and scoped invalid-frame count is zero; 21,504 other error/fault events remain retained, so no clean-log claim is made. Nine sparsely sampled recordings do not fill those limits.

## Category scores

| Category | Score | Assessment |
|---|---:|---|
| Visual hierarchy | 8.0 | Account guidance and actions compete at similar prominence; sign-in field grouping and the full-board footer need a calmer hierarchy. Clear titles and primary tasks remain identifiable. |
| Spacing/grid | 8.0 | Stable safe-area geometry and generally consistent margins; uniform sign-in child spacing and the capacity hint/status gutter mismatch weaken grouping. Account compact sections leave little distinction between help and actions. |
| Typography scale | 9.1 | Readable system typography and persistent Password label; hierarchy needs semantic grouping rather than smaller type. No observed text collision in reviewed sizes. |
| Dynamic Type | 9.0 | Default and XXXL retain fields, actions and scroll reachability. Capacity status keeps body sizing; short XXXL Island rows now both complete. Accessibility sizes 1–5 remain unobserved. |
| Light contrast | 9.4 | Reviewed light states retain strong labels and legal ink; native disabled controls are distinguishable. Any proposed secondary help treatment must preserve measured contrast. |
| Dark contrast | 9.4 | Dark forms, rows, error states and native Activity surfaces remain legible, with restrained separators and no decorative saturated panels. |
| Iconography | 9.3 | Branding and Apple mark are retained; completion, account and reorder affordances are coherent. Functional destructive trash color is appropriate. |
| Safe area / Dynamic Island | 9.2 | No observed obstruction in top, scrolled, keyboard and sheet states. The board's custom 24pt mask/6pt opaque accessibility boundary is distinct from Apple's native edge treatment. |
| Scroll/pull-down / last row | 9.4 | Long-board after-pull and true-bottom originals preserve the final row above the composer. New ordinary sign-in gestures establish real movement and bottom clearance in all four variants. |
| List rows | 8.7 | Large completion/reorder targets and first-line alignment work well. Persistent grips and reserved columns make long paragraphs visually denser than the short, varied Apple reference rows. |
| Empty states | 8.4 | All Clear is clear and the setup guidance is dismissible/focus-aware. The instructional empty state is substantially more text-heavy than Apple's minimal no-reminder surface. |
| Composer ergonomics | 9.1 | Multiline entry, Done, Add, retained draft and local completion are supported by captures/tests. At capacity Add disappears and full-width status preserves type; its repeated guidance still needs better hierarchy. |
| Keyboard handling | 9.2 | Full-device ordinary and combined-setting captures show keyboard clearance and persistent populated-password labeling. Protected XCTest screenshots are partial evidence; the separate native supplements fill that visual gap. |
| Sheet presentation/detents | 9.1 | Account large/medium and scrolled sheets use native detents and a hard native top edge. Local 46pt Done yields at least 44pt measured clearance/target behavior; dense content still scrolls. |
| Navigation clarity | 9.1 | Board, Account, Done and legal destinations are understandable. The recovery and draft paths retain context. |
| Touch targets | 9.4 | 44pt minimums are supported for main controls, password 48pt, legal links and local sheet Done. New ordinary pan evidence complements separate enabled appearance geometry rather than conflating the fixtures. |
| Haptics | 8.2 | Source supplies appropriate completion/reorder feedback paths. Simulator imagery and frame samples cannot establish physical haptic quality. |
| Animation/transitions | 8.5 | Sampled composer/account/Activity recordings show coherent states and no sampled-frame collision; three distributed frames per recording do not establish continuous smoothness or transition timing. |
| Loading states | 9.2 | Board and sign-in loading states retain clear status and stable control structure without layout collapse. No live-service timing inference is made. |
| Error states | 9.2 | Saved-board fallback, refresh recovery and sign-in error presentation are readable. Raw network error wording is intentionally retained; its length is a content constraint, not permission to remove it. |
| VoiceOver/labels | 8.9 | Source includes meaningful control labels, row position/move actions and avoids a duplicate spoken Password label. Spoken order and actual VoiceOver gestures were not heard or exercised. |
| iOS HIG consistency | 8.8 | Native list/sheet/keyboard affordances are strong. Account's help-heavy grouping and board custom edge differ from Apple's calmer references; semantic and configuration gaps prevent layout-copy conclusions. |
| Lock Screen / Live Activity | 8.9 | Native expanded and banner evidence supports line budgets/counts; native tightening fixes both short XXXL Island rows. Long rows still tail-truncate and compact/minimal are EmptyView; physical Lock/wallpaper variety is untested. |
| Sign-in/onboarding | 8.4 | Clear methods, persistent Password label, legal targets and actual scroll reachability. Equal spacing and primary-weight helper copy make the populated XXXL stack feel like a sequence of competing blocks. |
| Settings/account | 7.8 | The strongest observed crowding: five mixed status/action rows, exact multi-paragraph help, and expanded guidance stack without enough distinction of purpose. This is normal product copy, not a synthetic long-reminder artifact. |
| Performance feel | 8.3 | Fresh five-sample launch/scroll duration metrics provide a reproducible simulator baseline. No frame/hitch metric or hardware feel; host load, XCTest overhead and a 1389.957s keyboard runner outlier limit responsiveness conclusions. |
| Delight | 8.0 | The neutral post-it identity and focused completion flow are appealing. Dense explanatory surfaces interrupt the otherwise simple experience; user acceptance of visual calm is still open. |
| Long text | 8.4 | Board paragraphs wrap and remain reachable; Account preserves exact guidance and errors. Native Activity long rows retain safe tail truncation, so full identity of similarly prefixed reminders is not established at a glance. |
| Reduced Motion / Transparency | 9.2 | Actual Settings combinations and all four original values restored at each of three teardowns are evidenced. Opaque edge fallback and combined keyboard captures support current behavior; physical perception remains unmeasured. |
| Palette / minimalism | 9.3 | Neutral system surfaces, restrained separators and no nested decorative cards or decorative red/orange. Minimal palette alone does not resolve the observed information density. |

The JSON includes the complete screenshot/reference manifest, severity/confidence/source/check fields for each finding and explicit evidence gaps. Proposed density changes have not been implemented or tested in this review.

Written by gpt-6.1-sol in Codex on behalf of Edmund

