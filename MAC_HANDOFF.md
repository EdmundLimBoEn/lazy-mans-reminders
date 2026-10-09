# Mac handoff — Lazy Man's Reminders

Updated **9 October 2026**, audited at `c131c41`. This replaces the stale 7 August snapshot and its already-completed OAuth setup instructions. Use the reviewed release commit, not an old hardcoded tip.

Repository: `EdmundLimBoEn/lazy-mans-reminders`. Historical project records identify bundle `systems.edmundlim.LazyMansReminders`, widget `systems.edmundlim.LazyMansReminders.Widget`, App Group `group.systems.edmundlim.LazyMansReminders`, team `DUU8J39BA7`, ASC app `6799138197`. Confirm these in the signing account; this docs audit did not authenticate to Apple.

Canonical web: <https://lmr.sillyapps.co>; MCP: <https://lmr-mcp.edmundlim.systems/mcp>. Privacy/support are `/privacy` and `/support` on the canonical web host. Old-domain redirects and hosted Auth allowlists require the checks in [HUMANS.md](HUMANS.md).

## Build evidence

Use a Mac with a supported **release Xcode 26+ and iOS 26 SDK+**, XcodeGen and authorized Apple Developer access. Apple requires those upload minimums since 28 April 2026. The current iOS 17 deployment target exceeds Apple's effective iOS 13 floor. Stable Xcode 27 is supported by current Apple submission guidance; old beta builds 4/5 remain retired. [Official requirements](https://developer.apple.com/news/upcoming-requirements/).

The repository's [TestFlight workflow](.github/workflows/ios-testflight.yml) uses hosted macOS with latest-stable Xcode. It is a build route, not physical QA. Do not upload unreviewed PRs. Coordinate the reviewed commit, build number, signing configuration and upload authorization with Edmund.

1. Fetch the reviewed release commit on the Mac and record it with the build number.
2. Prepare ignored `ios/Config.xcconfig` from `ios/Config.example.xcconfig`; keep credentials, keys and certificates out of source, screenshots and logs.
3. Run `xcodegen generate` from `ios`, then open the generated project. Confirm app/extension team, IDs, App Groups, Apple login and production APNs entitlements in the signed archive.
4. Record `xcodebuild -version` and `xcodebuild -showsdks`; run the native simulator tests and archive the reviewed commit with release settings. Inspect actual archive SDK, minimum OS and embedded extension.
5. Inspect bundled privacy manifests, resolved SDKs, aggregate Xcode privacy report and icon. CI latest-stable selection and a repository manifest are insufficient evidence on their own.
6. Upload only after separate approval; wait for processing and install the exact resulting TestFlight artifact for QA. Keep beta external review distinct from App Store review.

## Physical-device release gates

Record device model, OS, build/commit, date, result and any screenshots. Complete [HUMANS.md](HUMANS.md#app-store-submission); do not mark tasks done solely because APNs accepted a request or source tests pass.

- Apple, Google, email magic link and reviewer existing-account login from fresh install; expired-session, cold-launch and poor-network behavior.
- Add/edit/complete/delete/reorder as supported by the selected build; web sync and capacity.
- Denied and allowed notification paths, Settings recovery and separate Live Activities setting.
- Lock Screen/Home Screen widgets, background activity updates/renewal/end, force-quit separately, and user dismissal. Follow [persistence QA](docs/live-activity-persistence.md).
- No stale private board, widget or activity after sign-out, account switching and deletion.
- Export and feedback routes; in-app deletion on disposable Apple/Google/email accounts with consent, including cancellation/failure/manual-revocation fallback and agent access cleanup.
- VoiceOver, Larger Text, contrast and Reduce Motion common tasks. Publish accessibility support only after criteria pass.
- Siri/Shortcuts only for features compiled into this artifact; test each phrase before advertising it.

## Submission preparation

[Apple requirements](docs/apple-release-requirements.md) maps sources to gaps; [submission notes](docs/app-store.md) provides draft metadata. Use the separate [reviewer provisioning guide](docs/reviewer-access.md) after its PR is integrated. Provision a stable confirmed synthetic account, enter credentials privately in ASC, verify access without the owner's inbox and keep it available throughout review. Apple self-signup alone is not a demonstrated review access solution.

Capture current required screenshot display groups and verify scaling in ASC, validate the archived icon, confirm actual Free pricing/availability, and complete age/privacy/encryption/DSA declarations. Edmund determines trader status; individual/free does not settle it. Check contact identity, phone/email, membership, agreements, roles and all public URLs. No identities, policy choices or credentials should be invented.

Use read-only preflight as one input; parser success does not certify native behavior or owner declarations. Human authorization is required before production deployment or App Review submission. This Linux work did not run Xcode or physical-device QA; no accessible interactive Mac build host was discovered or used.

Written by gpt-6.1-sol in T3 Code on behalf of Edmund
