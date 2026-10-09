# App Review account access

Checked against official documentation on 9 October 2026. This guide describes prerequisites; it does not contain credentials or claim that an account or selected build has been tested.

Apple [guideline 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness) requires a complete, working build, on-device testing, and demo account information for apps with login. Apple's [complete-review guidance](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review) asks for working username/password credentials in App Store Connect that remain valid throughout review. Asking reviewers to sign up or retrieve an expiring magic link leaves avoidable access dependencies.

## Provision manually before submission

An authorized human with access to the correct Supabase project must perform these steps. Do not provision a live account, send email, or change authentication settings through an automated release task without that authorization.

1. Verify that the selected iOS build points to the intended live backend and supports **Use an Existing Password** on the ordinary sign-in screen. Verify that Supabase email/password authentication is enabled and that project security requirements do not block this flow (for example, a required CAPTCHA not supported by this screen). Do not weaken project-wide security to accommodate review.
2. In the Supabase dashboard, manually create a dedicated ordinary email/password user using an address controlled by the developer. Explicitly mark the address confirmed during authorized provisioning, or complete confirmation yourself before review. Use a unique, strong password stored in a private password manager. No admin role, service-role token, privileged grants, or shared personal account is needed.
3. Verify the account is not banned and does not depend on MFA, email delivery, an expiring OTP, Apple/Google identity access, or an expiring invitation. Keep the credentials stable and the backend reachable for the entire review. If these conditions cannot be met under the project's policies, resolve reviewer access before submitting.
4. Sign in through the normal app using that account. Seed a small board of synthetic reminders through the ordinary UI (for example, “Water the sample plant” and “Read the sample book”). Include no personal information or real customer data, and no access to other users' boards.
5. Enter the actual email and password **only in the selected version's App Store Connect App Review sign-in fields**. Keep them out of repository files, PRs, tickets, screenshots, recordings, logs, build config, and public metadata. Fill the real App Review contact details separately.
6. In the review Notes, describe the public sign-in route: “On Sign In, choose Use an Existing Password, enter the credentials provided in the sign-in fields, and choose Sign In with Password.” Explain the board, widget setup, Live Activity, notification options, and any other non-obvious features of the selected build. No credentials belong in copyable notes in this repository.

This login works for any existing password account. The app has no password registration flow or reviewer-specific branch. Existing magic-link and Apple/Google options remain available. The password API is verified in the pinned [Supabase Swift v2.54.1 source](https://github.com/supabase/supabase-swift/blob/v2.54.1/Sources/Auth/AuthClient.swift#L449-L479); successful login uses the same session-sharing path as other providers.

## Validate the selected build

Run these checks on an actual iPhone with the exact build selected for review, recording the real build number, device, OS, and results privately. Simulator CI is useful but does not establish physical-device readiness.

- Start signed out; confirm Apple remains prominent, email uses magic link by default, and the password option is discoverable with VoiceOver and large text. Check secure entry, Password AutoFill, keyboard Next/Go/Done, and light/dark appearances.
- Sign in with the dedicated account. Verify incorrect credentials and offline failures show recoverable errors, repeated taps cannot start parallel requests, the password clears after an attempt, and choosing the sign-in link clears it. Check returning from background while a request is pending. If a view disappears, cancellation suppresses stale errors; a server-accepted login can still establish a session, because cancelling a task cannot undo backend authentication.
- Verify relaunch/session restoration, sign out and sign in again, and normal Apple, Google, and magic-link flows. Confirm magic-link inbox feedback and switching email still work. Perform these tests yourself; reviewers should not need inbox access.
- Test every shipped feature with this account: reminder create/edit/complete/delete, sync with the web board, widgets, Live Activity and its completion behavior, optional notifications, Siri on supported OS versions, settings, privacy/support links, export, and MCP authorization/revocation if offered. Test extensions after login and logout to confirm shared-session behavior. Do not claim untested features work.
- Test in-app account deletion on a separate synthetic account before preparing the final reviewer account. Confirm deletion is real and clears its data/session as intended. Keep deletion available to reviewers.

## If a reviewer deletes the account

Do not bypass deletion, exempt reviewers from cleanup, automatically resurrect users, or keep old tokens working. An authorized operator should privately recreate a dedicated confirmed account through normal Supabase administration, reseed synthetic reminders through the normal app, and verify login/full access again. Reuse the controlled email only if permitted and available; update the App Review sign-in fields with the actual working credentials whenever they change, and tell App Review privately that access has been restored. Never put replacement credentials in public comments or this guide. Monitor reviewer communication so deletion does not leave an unattended access failure.

## Outstanding human prerequisites

- [ ] Authorized manual account provisioning and synthetic seed data.
- [ ] Working stable credentials entered in App Store Connect for the selected version.
- [ ] macOS/Xcode simulator tests, archive validation, and all selected-build physical-device checks above.
- [ ] Private operator available to restore access after account deletion and respond to App Review.

Written by gpt-6.1-sol in T3 Code on behalf of Edmund
