# Notepad — iOS verification on a Mac

This handoff covers building and checking the iOS app on macOS. Linux cannot run Xcode, and hosted macOS CI is build/simulator evidence, not physical-device QA. This documentation refresh does not authorize an upload or App Store submission.

Repository: `EdmundLimBoEn/lazy-mans-reminders`. The iOS app display name is **Notepad**; the Xcode project and signing identifiers retain `LazyMansReminders`. `ios/project.yml` sets marketing version **1.0.1**, build-number floor **11**, and an iOS **17.0** deployment target. Verify the resulting artifact's version/build; do not assume the source pin is the latest TestFlight build.

| Identifier | Value |
| --- | --- |
| App bundle | `systems.edmundlim.LazyMansReminders` |
| Widget bundle | `systems.edmundlim.LazyMansReminders.Widget` |
| App Group | `group.systems.edmundlim.LazyMansReminders` |
| Team | `DUU8J39BA7` |
| App Store app | `6799138197` |

Confirm signing identifiers in the authorized account. No Apple account state was checked for this refresh.

## Addresses to check

- Web board: <https://app.notepads.dev>; landing: <https://notepads.dev>.
- Privacy: <https://app.notepads.dev/privacy>; terms: <https://app.notepads.dev/terms>; support: <https://app.notepads.dev/support>. Contact: `edmund@sillyapps.co`.
- Legacy web: `https://np.sillyapps.co` and `https://lmr.sillyapps.co` stay live without a 301; `https://lazy-mans-reminders.pages.dev` is the fallback. The same legal/support paths exist on those hosts. `https://lmr.edmundlim.systems` stays attached and 302s to `lmr.sillyapps.co`, preserving path and query.
- MCP: <https://np-mcp.sillyapps.co/mcp>; legacy <https://lmr-mcp.edmundlim.systems/mcp> stays live without a 301.
- iOS magic-link handoff: `https://app.notepads.dev/auth/ios`. Custom callback: `lazymansreminders://auth/callback`.

The repo's Supabase Site URL remains `https://np.sillyapps.co`; current clients use `app.notepads.dev`. See the [exact redirect allowlist](README.md#authentication-configuration). Verify hosted Auth settings separately from local config.

## Build checklist

Use a Mac with Xcode and XcodeGen. `ios/project.yml` and native workflows select **Xcode 27.1**; workflows use the `xcode-27` runner. Recheck Apple's upload requirements before an authorized release; [the requirements audit](docs/apple-release-requirements.md) is dated evidence.

The [TestFlight workflow](.github/workflows/ios-testflight.yml) runs on pushes to `main` touching `ios/**`, `scripts/**`, or that workflow file, and on `workflow_dispatch`. Merges into `dev` do not upload. Feature/fix PRs target `dev`; releases go from `dev` to `main` as described in [AGENTS.md](AGENTS.md). Coordinate the reviewed commit, signing configuration, build number, and upload authorization with Edmund.

1. Fetch the reviewed commit on the Mac and record it with the build number.
2. Prepare ignored `ios/Config.xcconfig` from `ios/Config.example.xcconfig`. Keep credentials, keys, and certificates out of source, screenshots, and logs.
3. Run `xcodegen generate --spec ios/project.yml`, then open `ios/LazyMansReminders.xcodeproj`. Confirm both targets' team, identifiers and App Group, app Sign in with Apple, and production APNs entitlements in the signed archive.
4. Record `xcodebuild -version` and `xcodebuild -showsdks`. Run `scripts/check-ios-toolchain.sh`, `scripts/ios-release-build.sh`, and `scripts/ios-simulator-unit-tests.sh` from the repo root. Archive the reviewed commit with release settings; inspect its SDK, minimum OS, and embedded widget.
5. Inspect bundled privacy manifests, resolved SDKs, aggregate Xcode privacy report, default icon, and alternate icon entries. Source files and CI toolchain selection alone do not establish archive contents.
6. Upload only after separate authorization. Install the exact processed TestFlight artifact for QA; keep beta review distinct from App Store review.

## Physical-device checklist

Record device model, OS, artifact version/build, commit, date, and results. Historical checkmarks in [HUMANS.md](HUMANS.md) do not validate a new artifact.

- Test Apple, Google, email magic link, and existing-account password login from a fresh install, including expired sessions, cold launch, and poor connectivity. Verify canonical and legacy redirect paths.
- Add, edit, complete, delete, and reorder reminders; check web sync and capacity. Verify done-row cleanup after 3 days from `completed_at`, allowing for best-effort execution.
- Create/edit a routine on the web, then receive and complete its generated reminder on iPhone. Routine editing is on the web.
- Test denied/allowed notifications, Settings recovery, and the separate Live Activities setting.
- Check Lock Screen and Home Screen widgets, activity updates/renewal/end, user dismissal, and force-quit separately. Follow [persistence QA](docs/live-activity-persistence.md).
- Confirm no stale private board, widget, or activity remains after sign-out, account switching, or deletion.
- Test export, feedback, support/privacy links, and deletion on disposable Apple/Google/email accounts with consent. Include cancellation, failures, manual Apple-revocation fallback, and agent-access cleanup.
- Switch between **Default**, **Minimal**, and **Bold** in Settings; restore Default, relaunch, and confirm the selected icon/checkmark.
- Test VoiceOver, Voice Control labels, **Move up / Move down** actions, Larger Text, Reduce Motion, Increase Contrast, Reduce Transparency, and readable error text. Publish accessibility support only after device QA passes.
- Test “List reminders in Notepad”, “Add a reminder in Notepad”, and “Mark this as done in Notepad” with Siri/Shortcuts. Signed-out requests should ask you to sign in to Notepad on this iPhone first. Advertise only behavior verified in the selected artifact.

## Release preparation

Use [submission notes](docs/app-store.md) for metadata and the [reviewer-access guide](docs/reviewer-access.md) for private account preparation. Confirm working reviewer access from a fresh install, keep credentials only in private review fields, and use a separate disposable account for deletion QA.

Capture current required screenshots, check the archived icons, confirm Free pricing with no in-app purchases, and review privacy, age, encryption, availability, and trader declarations with Edmund. Verify all public URLs and contact details. Read-only preflight is one input; it does not certify native behavior or owner declarations.

Production deploys are performed by jeremy after Edmund's explicit OK. App Store submission requires separate authorization and release evidence; no submission is part of this documentation work.
