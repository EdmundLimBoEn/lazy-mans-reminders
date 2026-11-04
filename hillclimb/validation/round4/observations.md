# Observations for parent review

The required normal-settings suite passed285/285. This is validation evidence, not UI acceptance or a score. No application or existing test source was edited.

The default full-board bottom still shows preceding-row fragments against the top header edge. This is observed in core full-*-default-bottom-after-pull.png and board/*-default-true-bottom-after-pull.png. Final-row ink and composer clearance passed. The prior H report already disclosed this residual top-edge issue; it is not silently marked resolved here.

Selected actual-system accessibility configuration exposes a keyboard evidence concern. In accessibility/signin-light-XXXL-all-three-settled.png, Reduce Motion, Reduce Transparency and Increase Contrast were enabled through native Settings. Done is visible at48pt, but Use an Existing Password is outside the captured visible form and absent from that visible AX snapshot. This is one observed viewport after a real pan, not a diagnosed source defect or proof that the alternate action is unreachable. No complete accessibility-setting keyboard matrix or clearance pass is claimed. Parent should inspect and reproduce the lower-form scroll position before deciding whether a source fix is needed. The eight normal-settings cases separately passed every original assertion and show the alternate action with at least116pt clearance.

Two capture-only problems are retained. A Motion label-row tap returned0 without changing the underlying switch; its false enabled image is excluded under accessibility/rejected. Native UISwitch input then confirmed On. A later field tap opened an AutoFill context menu; that image is retained and excluded, with the separate settled image above. The combined-settings recording includes that menu segment and must not be presented as a clean keyboard sequence. A stale-ref tool error while restoring Increase Contrast was retained; following its fresh-snapshot hint once succeeded. All three settings are proven restored to original Off.

The old bottom-repair helper assumed every earlier capture was a short scroll. Both round4 earlier originals visually reached the last row too. Their original reason is retained in originalHarnessReason; the corrected reason says superseded by explicit geometry verification. Both originals remain under rejected as excluded duplicates. No actual failure is invented.

Native Activity conserves10 input lines. Notification Center banners show5+5/default and4+6/XXXL. Expanded Island frames show3+7/default and2+8/XXXL. XXXL Island mid-word truncation remains visible. Four compact/minimal images intentionally contain no Activity text. Notification Center is not a truly locked device. Twelve unit-rendered rasters are separate from native evidence.

Spoken VoiceOver/traversal, physical haptics, true physical Lock Screen, arbitrary wallpapers, AX1-AX5 native layouts, physical performance feel and launch/frame-time metrics remain unverified. Notes and exact Apple authentication/Activity/error references are absent. Account is paired with Reminders Details with semantic/detent/paragraph differences disclosed. Enabled sign-in and Account are safe local design fixtures, not tested live service flows.

Written by gpt-6.1-sol in Codex on behalf of Edmund
