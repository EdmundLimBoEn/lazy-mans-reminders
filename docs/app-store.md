# App Store Connect notes

Draft source for the **free 1.0** submission, app id `6799138197`. Updated **9 October 2026**. Not submitted or certified ready. Read [Apple requirements and evidence gaps](apple-release-requirements.md) and [HUMANS.md](../HUMANS.md) before applying fields. Earlier 27 October/30 November targets are internal plans, not Apple deadlines; release follows evidence and Edmund's approval.

The native display name is **Lazy Man's Reminders**. Earlier records say ASC used **Lazy Mans Notepad**; confirm and update the actual listing. No current authenticated ASC state was verified for this docs change. There is no Fastlane metadata tree.

## Listing copy

| Field | Draft value | Limit |
|---|---|---|
| Name | `Lazy Man's Reminders` | 20 / 30 characters |
| Subtitle | `Lock Screen reminder board` | 26 / 30 characters |
| Locale | `en-US` | Primary locale |
| Category | Productivity | Confirm in ASC |
| Keywords | `reminders,lock screen,live activity,todo,board,siri,widget` | 100 bytes |

Description (4000-character limit):

```text
Lazy Man's Reminders is a small reminder board for your iPhone, the web, and the Lock Screen.

Add a few lines and keep the same board on your iPhone and at https://lmr.sillyapps.co. Complete lines as you finish them.

Add Board widgets to your Home Screen or Lock Screen. A Live Activity can show active reminders on the Lock Screen while Live Activities are enabled. Its availability and updates depend on iOS settings, network access, and system limits.

Sign in with Apple, Google, or email. Connect an agent through MCP if you want to let it manage your reminders.

Push banners are optional. The in-app board works when notifications are off.

Free. No in-app purchases. No subscriptions.

Privacy: https://lmr.sillyapps.co/privacy
Support: https://lmr.sillyapps.co/support
```

Promotional text: `A small reminder board for your iPhone, the web, and the Lock Screen.`

What's New (1.0): `First release of Lazy Man's Reminders.`

Only add Siri/Apple Intelligence claims or exact phrases after testing them in the selected signed build. App Intents source/SDK guards are not runtime evidence. Do not promise uninterrupted or indefinite Live Activity persistence.

Apply localization fields in App Store Connect → App Information and the iOS 1.0 version. If using `asc`, inspect the installed command help before applying; do not assume old command syntax still works. Confirm saved values before submission. This docs work does not authorize external writes or submission.

## URLs and support

- Privacy: <https://lmr.sillyapps.co/privacy>
- Support: <https://lmr.sillyapps.co/support>
- Marketing: <https://lmr.sillyapps.co>
- Terms: <https://lmr.sillyapps.co/terms> (optional metadata)
- Contact: `hello@edmundlim.systems` (human must confirm monitored inbox)

Historical checks report that `lmr.edmundlim.systems` redirects with 302; do not assume production redirect/auth settings match repository config. Check all URLs unauthenticated from outside the home network.

## Pricing, availability, content rights and DSA

Intent: **Free**, no IAP/subscriptions, all eligible territories including new territories. Owner must confirm actual zero price and availability; decide compatible Mac/Apple Vision Pro distribution separately. Confirm copyright and rights to all bundled/marketing assets; private reminder text is user-authored.

**Do not infer trader status from being an individual or from free pricing.** Edmund must assess whether the app is offered in connection with commercial activity and declare the result. If a trader distributing in the EU, provide and verify Apple's required public contact information and other declarations. Do not invent a company, address, phone, VAT or registration number. [Apple DSA guidance](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements).

## Age rating and encryption

Complete the current questionnaire and confirm the resulting global/regional ratings. **4+ is a hypothesis, not a completed submission fact.** This is not a Kids Category app and baseline has private reminders rather than a public social feed. Review all capabilities, including UGC, messaging, browsing, ads and controls. Social-media questions added 9 July 2026 became required in September 2026. [Apple age notice](https://developer.apple.com/news/?id=tlur8uvi).

`ITSAppUsesNonExemptEncryption=false` is configured. It means no encryption or only exempt encryption, including dependencies; it is not a blanket answer of No to every encryption question. The app uses HTTPS and CryptoKit hashing. Edmund must confirm classification in Apple's questionnaire for the final artifact and upload documentation if required. [Apple key semantics](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).

## App Privacy

The manifest and ASC privacy labels are separate declarations. Audit actual app, backend and integrated partner collection before saving labels. The policy discloses provider profile metadata and operational logs beyond the manifest's four current types; **do not automatically exclude Name or Diagnostics** without investigating retained fields and disclosure criteria. [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/).

Baseline manifest proposal, pending the audit:

| Data | Proposed purpose/linkage | Evidence |
|---|---|---|
| Email Address | App Functionality; linked | Account sign-in |
| User ID | App Functionality; linked | Supabase identity |
| Other User Content (reminder text) | App Functionality; linked | Board sync |
| Device ID | App Functionality; linked | APNs/Live Activity tokens; verify classification |

Baseline declares no tracking or advertising; verify actual integrated services. Nutrition labels must cover actual collection and relevant purposes, not merely visible UI. Optional beta feedback has separate disclosure criteria.

`NSPrivacyAccessedAPICategoryUserDefaults` reasons concern API access, not collected-data types. Current `1C8F.1` covers App Group sharing; app-only `.standard`/`@AppStorage` use needs an applicable reason audit. A separate PR owns fixes. Review the final archive's manifests, resolved SDKs and aggregate privacy report before uploading.

## Review notes

**Submission blocker: provision and verify reviewer access first.** The separate [reviewer-access PR #52](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/52) adds existing-account email/password login and a [secure provisioning guide](reviewer-access.md). That guide does not mean a real account exists or that the feature is integrated into the selected binary. A stable, confirmed synthetic reviewer account, private credentials and fresh-install QA remain human prerequisites. Keep actual credentials out of this repository; enter them in ASC's dedicated account fields. Sign in with Apple self-signup alone is not verified reviewer access. [Apple review information](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review).

Set sign-in required to **yes** and provide verified access, contact first/last name, reachable phone/email and any additional authentication instructions. Do not paste `none yet`, blank credentials, or fabricated accounts into a submission. Confirm the credentials remain usable throughout review. TestFlight external beta review needs the same access preparation.

Draft non-secret review notes, to edit after selected-build QA:

```text
This is a private reminder board. Sign-in enables synchronization with https://lmr.sillyapps.co, device registration for APNs, and optional agent access through MCP. Review account credentials are provided in the dedicated account fields.

On Your Board, add a reminder, complete it with the circle or swipe action, and refresh to see changes from the web board on the same account.

Add Board widgets from the Home Screen or Lock Screen widget picker. With Live Activities enabled, an active board can appear on the Lock Screen. The backend attempts periodic updates and renewal; availability is controlled by iOS, settings and connectivity. Complete or delete all reminders to end the active board. Removing a Live Activity and disabling Live Activities should be tested separately.

Notification banners are optional. Deny notification permission and verify the board still works. Live Activities have a separate system setting.

Account → Delete Account initiates account and associated-data deletion. Validate Apple-token revocation and any manual-revocation fallback before describing them as complete. Use a disposable account to test deletion; deleting the main review account will invalidate its access.

Account → Download My Data opens the web board, where a signed-in user can export their data.

Free. No IAP or subscriptions. Support: hello@edmundlim.systems.
```

Replace the validation sentence with the actual tested deletion/revocation behavior before submission. Add Siri instructions only if verified in the selected build; document any hardware/setup/resources needed. [Account deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/).

## TestFlight beta

Populate Test Information before external invites:

| Field | Draft value |
|---|---|
| Feedback email | `hello@edmundlim.systems` |
| Marketing URL | `https://lmr.sillyapps.co` |
| Privacy URL | `https://lmr.sillyapps.co/privacy` |
| Beta App Description | Use the tested capabilities from Listing copy; describe it as a beta |
| Beta review access | Verified synthetic account, private credentials, contact and notes as above |

What to Test (edit to the selected build):

1. Try Apple, Google and email authentication, including cold-launch and expired-session recovery. Test existing-account password login when its PR is integrated.
2. Deny notification permission first; confirm board usability. On a second pass enable banners and add a line from the web board.
3. Enable Live Activities separately. Open the signed-in app to register tokens; test active lines, background renewal and completing the final line. Record OS/build/device, not just APNs acceptance.
4. Add Lock Screen and Home Screen Board widgets; compare active lines with the app.
5. Check poor connectivity, sign-out, and sign-in to another account for stale private data.
6. Test export, feedback and deletion using disposable accounts with consent. Cover Apple confirmation cancellation, revoke errors and manual fallback, plus email/Google deletion.
7. Try VoiceOver, Larger Text, contrast and Reduce Motion on sign-in, board and account actions.
8. Follow [persistence QA](live-activity-persistence.md) and record observations. Long persistence/soak targets are project gates, not Apple-prescribed durations.

## Screenshots and icon

Use the **current named display groups** from [Apple's specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). The page lists iPhone with Dynamic Island **medium display** as required (1179×2556 or 1206×2622 portrait) and describes scaling fallbacks. Capture/verify that coverage in ASC; the old `APP_IPHONE_69` flag alone does not establish it. A large Dynamic Island set may also use 1260×2736, 1290×2796 or 1320×2868. Preview accepted uploads/scaling rather than guessing ASC API display identifiers.

Apple's [ScreenshotDisplayType API enum](https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype) ([official DocC JSON](https://developer.apple.com/tutorials/data/documentation/appstoreconnectapi/screenshotdisplaytype.json)) lists `APP_IPHONE_67`, `APP_IPHONE_65`, `APP_IPHONE_61` and older sizes, **not `APP_IPHONE_69` or `APP_IPHONE_63`**. The enum descriptions do not map these legacy identifiers to current named groups or dimensions. The help page permits medium Dynamic Island scaling from Face ID large and large Dynamic Island scaling from Face ID large. Confirm actual set type, dimensions, delivery state and ASC preview/scaling; do not infer exact current-group mapping from the enum suffix alone. No authenticated upload/acceptance experiment was performed.

Baseline is iPhone-only (`TARGETED_DEVICE_FAMILY=1`); iPad screenshots apply if support changes. Use opaque JPEG/PNG, 1–10 per display size. Use actual app captures with fictional non-sensitive text. Repo convention: no frames and no login-only set. Those conventions are not a claim that Apple forbids every login screenshot or device frame.

Suggested 5–6 shots: board with composer, completion action, Live Activity, Lock Screen Board widget, Home Screen Board widget, Account with optional notifications. Verify each feature on the selected build before capture. Screenshots are not stored here. Check the universal 1024×1024 icon asset in the archive and product-page rendering; a source file alone is not acceptance evidence.

## Preflight and final human gates

```sh
./scripts/asc-preflight.sh
```

The script is read-only and never submits. Its baseline version can falsely pass version, screenshot, review and pricing checks; see the [audit](apple-release-requirements.md#read-only-preflight-audit-script-unchanged). Another PR owns script changes. Its revised design deliberately reports UNKNOWN and exits nonzero for API-unverifiable evidence; resolve those items with actual evidence and a manual release decision, not a forced green report. Preflight does not certify privacy, age, DSA, encryption, SDK/signing, reviewer access or physical QA.

All human prerequisites are tracked in [HUMANS.md](../HUMANS.md#app-store-submission). Native build handoff is in [MAC_HANDOFF.md](../MAC_HANDOFF.md). Hosted macOS CI exists, but this Linux docs work did not run Xcode, upload a binary, inspect authenticated ASC state, deploy changes or submit review. Edmund must review evidence and authorize release.

Written by gpt-6.1-sol in T3 Code on behalf of Edmund
