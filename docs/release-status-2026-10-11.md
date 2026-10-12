# Release status, 11 October 2026

Public release remains blocked by the reported Live Activity disappearance and the remaining device and App Store Connect gates. This record supersedes older deployment/version assumptions; it does not certify release readiness.

**12 October update:** [Authenticated App Store state](app-store-state-2026-10-12.md) records saved metadata/review access, published privacy labels, the non-trader declaration and processed build 22. The archive numbers below are not the exported TestFlight numbers: export renumbered archive 9 to uploaded build **21**, and the subsequent archive 10 to uploaded build **22**. Both mappings were verified against the upload IDs in CI and App Store Connect.

## Code and signed artifact

The original local checkout was at `c131c41` with unfinished changes. Verification and deployment used the clean upstream commit `c65ef2a31be0fa403c1dfb53c544777e1a2f0e0c`. Existing changes in that original checkout were left intact.

Merged PRs #52, #55, #57, #58, #59 and #60 already supply password reviewer login, Apple cancellation/session checks, revocation retries and manual fallback, revised listing copy, and the evidence-based preflight. They were not reimplemented here.

[TestFlight run 38131374027](https://github.com/EdmundLimBoEn/lazy-mans-reminders/actions/runs/38131374027) used that commit. Its logs show **167 tests with zero failures**, successful archive/export, and successful upload. The `ios-archive-sdk-metadata` artifact identifies both the app and embedded widget as **1.0 (9)**, Xcode **26.6** (`2660`, build `17F113`), SDK **iphoneos26.5** (`23F81a`), and minimum iOS **17.0**. These meet Apple's currently published SDK and deployment floors. [Apple requirements](https://developer.apple.com/news/upcoming-requirements/).

Successful upload is not evidence of Apple processing, TestFlight availability, physical-device behavior, aggregate privacy-report review, or App Review approval. App Store Connect requires sign-in in the shared browser, and no authorized API token was present for the live preflight.

## Backend deployment and checks

Production initially ran deletion function version 7, whose downloaded source lacked the merged retry/fallback changes. After 77 backend tests and the deletion entry-point type check passed, the reviewed function was deployed to the intended Supabase project as **version 8**. JWT verification remains enabled. A fresh source download matched all six bundled repository files, and an unauthenticated POST returned **401**.

The function retries revocation with the exchanged token rather than reusing Apple's single-use authorization code. When automatic revocation cannot complete, it returns `appleRevocation: manual_required`; native and web clients explain how to revoke Apple access manually after app-data deletion. Apple explicitly documents deleting app data and directing manual revocation when the necessary Apple credentials are unavailable. [Apple TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple).

No existing user account or reminders were deleted for validation. Real Apple success/failure paths, web/native deletion, connected-agent revocation and session cleanup still require the disposable-account device tests in [HUMANS.md](../HUMANS.md).

Web verification passed **88 tests**, lint and the production build. The deployed web bundle contains the deletion fallback and optional-password privacy disclosure. Public `/privacy`, `/support` and `/terms` returned **200**. No web redeployment was needed. The revised preflight's **49 unit tests** also passed; those fixtures are not live ASC evidence.

## Reviewer access

Under the user's authorization, a dedicated ordinary confirmed review account was provisioned without changing project-wide authentication settings or sending email. Password authentication was verified against the live backend. Two fictional reminders were seeded and read using the account's own authenticated session, rather than administrator access.

Credentials are stored only in the operator's private local account record with permissions **0600**, outside the repository. This document deliberately contains no email, password, user ID or tokens. They must be entered into the selected version's private App Review sign-in fields, never public notes. Verify the ordinary **Use an Existing Password** flow on the exact signed iPhone build before claiming reviewer access is ready. See [reviewer access](reviewer-access.md).

## Remaining release gates

- Repair the overnight disappearance and failed recovery after reopening. The requested separate GPT-6.1 Sol max thread owns this fix and its build/deployment verification. Repeat normal-background, renewal, foreground recovery, dismissal, empty-board, and account-switch tests on the resulting build.
- Install the processed release candidate on a physical iPhone and finish sign-in, widgets, notification permissions, Siri, accessibility, deletion, and the project's overnight/soak checks.
- Verify Apple processing and tester availability. Review final archive privacy manifests and SDK disclosures against the App Privacy declarations.
- Enter the prepared review account privately in ASC, confirm native reviewer access, and keep it valid throughout review.
- Complete listing name/copy, current screenshots, contact details, age questionnaire, export compliance, free pricing/territories and the correct EU DSA declaration in authenticated ASC.
- Submit only after the remaining gates are satisfied. No App Store submission was performed.

Written by gpt-6.1-sol in T3 Code on behalf of Edmund
