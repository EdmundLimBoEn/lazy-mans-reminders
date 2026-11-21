# Review contract

Compare every captured state with paired Apple Reminders and Notes references from the same regular iPhone 17 Pro in hillclimb/reference/. Target Apple-native polish, not copied layout. Missing references are evidence gaps. Reviewers never edit application code. Grade screenshots AND SwiftUI source independently. Do not infer runtime success from code alone; mark unobserved behavior explicitly. Overall is the arithmetic mean of category scores, rounded to 2 decimals. Stop gate: both requested Codex models and Claude Opus 5.5 overall >=9, each category >=7. No inflated scores to meet the target.

Taste: minimal Apple-native/Cursor-like; no nested cards, no red/orange decorative palette. Preserve all user-facing wording, branding and icon.

Categories

1. Visual hierarchy
2. Spacing/grid
3. Typography scale
4. Dynamic Type
5. Light contrast
6. Dark contrast
7. Iconography
8. Safe area / Dynamic Island
9. Scroll/pull-down / last row
10. List rows
11. Empty states
12. Composer ergonomics
13. Keyboard handling
14. Sheet presentation/detents
15. Navigation clarity
16. Touch targets
17. Haptics
18. Animation/transitions
19. Loading states
20. Error states
21. VoiceOver/labels
22. iOS HIG consistency
23. Lock Screen / Live Activity
24. Sign-in/onboarding
25. Settings/account
26. Performance feel
27. Delight
28. Long text
29. Reduced Motion / Transparency
30. Palette / minimalism

Every finding: severity, screen/evidence, concrete fix, confidence and whether observed or source-derived. Save scores-<model>.md and scores-<model>.json; PM aggregates scores.json. Include source SHA, screenshot manifest, evidence gaps, overall and each category.

Written by gpt-6.1-sol in Codex on behalf of Edmund

## Programmatic gates

For each measurable finding, require a regression check plus the existing iOS suite. Priorities: long-board pull/scroll bottom row fully visible above composer, top safe-area and Island non-overlap, XXXL long-text truncation, and 44pt touch targets. Source-only assertions cannot establish on-device geometry. Record command, result, source SHA and evidence. Never claim unrun checks passed.
