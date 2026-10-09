# Apple release requirements and gaps

Researched **9 October 2026** against primary Apple sources. Implementation evidence is from **c131c41**; pending changes in other PRs are not counted as shipped. This is a source and repository audit, not App Store Connect certification or physical-device QA. Linux cannot run Xcode locally; the repository has a hosted macOS build workflow, but no new build was run for this docs change.

Use [app-store.md](app-store.md) for draft submission copy, [HUMANS.md](../HUMANS.md) for every human prerequisite, and [MAC_HANDOFF.md](../MAC_HANDOFF.md) for native verification. Existing deployment/checkmark history is not proof that the selected release artifact passes these gates.

## Published dates

| Requirement | Published/effective date | Application here |
|---|---|---|
| Xcode 26+ and iOS 26 SDK+ for uploads | Notice 3 February 2026; effective **28 April 2026** | Verify the actual archive; iOS 17 deployment target can remain. [SDK notice](https://developer.apple.com/news/?id=ueeok6yw), [requirements](https://developer.apple.com/news/upcoming-requirements/) |
| iOS/iPadOS deployment target at least iOS 13 | Effective **9 September 2026** | `ios/project.yml` targets 17.0, already above this floor. [Apple notice](https://developer.apple.com/news/upcoming-requirements/?id=0992026a) |
| Updated age questionnaire | Deadline **31 January 2026** | Complete current questions, not a historical rating. [Apple notice](https://developer.apple.com/news/upcoming-requirements/?id=07242025a) |
| Social media capability questions | Notice **9 July 2026**; required starting **September 2026**, no day specified | Private reminders have no social discovery feed in this baseline; owner must answer for the actual release. [Apple notice](https://developer.apple.com/news/?id=tlur8uvi) |
| Required reason API declarations | Effective **1 May 2024** | Audit first-party and dependency use. [Requirements](https://developer.apple.com/news/upcoming-requirements/) |
| In-app account deletion | Effective **30 June 2022** | Verify deletion and Apple revocation paths. [Account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/) |
| EU trader status | EU updates from **16 October 2024**; removal without verified status from **17 February 2025** | Owner declaration remains needed. [Requirements](https://developer.apple.com/news/upcoming-requirements/) |

Apple also publishes an **April 2027** SDK 27 upload requirement and iOS 15 deployment floor; no exact day appears on the [submission page](https://developer.apple.com/app-store/submitting/). The [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) publish an April 2027 iPhone Duo screenshot requirement for apps using iOS 27.1 SDK+. These are future requirements, not October 2026 gates. Recheck Apple sources immediately before upload/submission. Stable Xcode 27 is promoted on Apple's current submission page; the old beta builds 4/5 are historical, not evidence that all Xcode 27 builds are rejected.

## Release evidence checklist

### Build, completeness, and review access

Apple expects device testing, accurate metadata, reachable services, and reviewer access. Account-based apps need a working demo account or full demo mode; guideline 2.1's legal/security exception requires prior approval for its substitute demo mode. Google login calls for an equivalent privacy-preserving login option under 4.8; Apple login exists here. [Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [review information](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review).

- [ ] Archive with a supported **release** Xcode/SDK, record versions/build number/commit, and attach the processed artifact. `ios/project.yml` says Xcode 16.0; CI selects `latest-stable`, prints SDKs and runs simulator tests, but neither alone proves the selected archive's toolchain or runtime behavior.
- [ ] Integrate and review [#61 — publication safety](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/61): a suspended old-account Spotlight/Live Activity publication must not restore private data after completed cleanup or a direct account switch. Cover identifier/full reindex routes, reloads and notifications using the physical QA in HUMANS.md; source review does not certify system behavior.
- [ ] On a physical iPhone, test Apple/Google/email sign-in, cold launch, expired session, CRUD/sync, poor connectivity, widget, Live Activity, export, and deletion. Capture results per build, OS, and device. Reuse `docs/live-activity-persistence.md` for the soak; neither a 24-hour soak nor seven days is an Apple-prescribed duration.
- [ ] Resolve reviewer access. No guest/demo board or reusable reviewer credentials were found at baseline. The separate [reviewer-access guide](reviewer-access.md) accompanies existing-account password login; provision/verify a real synthetic account after integration. Apple self-signup and an email magic link dependent on the owner's inbox are not a proven access solution. Test a dedicated account or full demo path from a fresh install, including authentication codes and backend features; put sensitive access details only in ASC. Obtain approval where the exception applies.
- [ ] Set review contact first/last name, reachable phone/email and build-specific notes. Describe sync, optional notifications, widget setup, Live Activity renewal, deletion and any external hardware/resources. Complete equivalent TestFlight beta review information before external testing.
- [ ] Remove promises of uninterrupted Lock Screen persistence or untested Siri capabilities from submitted metadata. OS/user/network settings control activities; SDK compilation does not prove Siri phrases work.

### Account deletion and Sign in with Apple

Apple requires in-app initiation of account/data deletion and token revocation for Apple users. [Deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/) and [TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple) cover unavailable-token/manual-revocation handling. Deletion must still be fulfilled when a token cannot be obtained; do not retain an account indefinitely to wait for Apple.

Evidence: `ios/App/AccountView.swift`, `AppleRevocation.swift`, `supabase/functions/delete-account/handler.ts`, `_shared/apple_token_revoke.ts`, `_shared/account_tables.ts` implement confirmation, fresh-code exchange, revocation, agent-grant cleanup, data cleanup and auth deletion. Tests exist. **Gap:** Apple cancellation/missing code/secrets/revoke failures can still yield successful deletion; warning logs do not prove revocation. Web Apple deletion also needs coverage.

- [ ] Implement/verify successful revocation or TN3194-compatible fallback with clear manual revocation instructions and revoked-credential handling; test cancellation, network errors, missing configuration and web/native paths.
- [ ] Integrate and validate [#60 — bounded OAuth grant cleanup](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/60): the baseline shared helper has no fetch/body deadline and can stall deletion. Confirm timeout/error paths return promptly and preserve the existing failure response before destructive cleanup; keep this separate from Apple-token revocation.
- [ ] Confirm reviewed backend version/secrets are deployed through a separately authorized release; validate on a disposable account with consent, including all owned data/grants, session/cache cleanup and retention/backups disclosures. Existing deployment notes are historical evidence only.

### Privacy policy, labels, manifest, permissions, and SDKs

[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) requires disclosures for actual collection by the app and integrated partners. ASC labels, a public policy, and the bundle manifest are distinct artifacts. The manifest is an audit input, not a complete label answer sheet. Check collection/linkage/purpose/tracking and optional-disclosure criteria for each data flow.

Evidence: `web/src/LegalPages.tsx` documents account/profile metadata, reminders, push tokens, preferences, agent access, logs and optional TestFlight feedback. Sign-in and Account link to privacy. `ios/Shared/PrivacyInfo.xcprivacy` declares email, user ID, user content, device ID, App Functionality, linked, no tracking. Both native targets include it through XcodeGen. Supabase Swift is pinned to 2.54.1; resolved transitive packages still need inspection.

- [ ] Reconcile actual Supabase provider metadata (including possible **name**), backend/hosting diagnostics and identifiers with labels/policy. Do not blindly exclude Name or Diagnostics. Assess beta feedback against Apple's disclosure rules separately from release collection. Confirm contact, retention, deletion and all policy URLs from a clean network session.
- [ ] Fix required-reason coverage: manifest has UserDefaults **1C8F.1** for App Group sharing; `PushTokenRegistrar` uses `.standard` and `ReminderListView` uses default `@AppStorage`, needing an app-only reason such as **CA92.1** where applicable. Audit all other categories and resolved dependencies. [Approved reasons](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
- [ ] Inspect the final app/extension manifests and Xcode aggregate privacy report, package resolution and Apple's listed SDKs. Required SDK manifests apply to listed/repackaged SDKs; signatures apply to listed SDK binary dependencies. Do not require a signature on every source package or assume absence from the list eliminates API declarations. [SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/), [manifest guidance](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).
- [ ] Audit protected APIs/purpose strings against the selected artifact. No camera/microphone/photos/contacts/location permission was found in baseline plists; do not add unused access. ATT is not implied by account linking; tracking changes require a fresh audit. [Protected-resource access](https://developer.apple.com/documentation/bundleresources/protected-resources).
- [ ] Verify consent and denial paths. `NotificationAccessPolicy` and `AppDelegate` request notification authorization; notifications do not use an Info.plist camera-style purpose string. Test no repeated prompts, denied-state usability, alert opt-in and separate Live Activity settings. [Notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications).

### Product page assets and metadata

The live [screenshot specification](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) lists **iPhone with Dynamic Island (medium display)** under required sizes, accepts 1179×2556 or 1206×2622 portrait, and describes scaling fallbacks. It also lists large Dynamic Island sizes (1260×2736, 1290×2796, 1320×2868) and Face ID large sizes (1242×2688, 1284×2778). Provide actual captures for required slots and verify ASC's accepted scaling; the old `APP_IPHONE_69` check alone is insufficient. Images must be opaque; 1–10 per size. iPad assets apply only if supported; device family is `1` here.

Apple's [ScreenshotDisplayType API enum](https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype) ([official DocC JSON](https://developer.apple.com/tutorials/data/documentation/appstoreconnectapi/screenshotdisplaytype.json)) lists `APP_IPHONE_67`, `APP_IPHONE_65`, `APP_IPHONE_61` and older sizes, **not `APP_IPHONE_69` or `APP_IPHONE_63`**. The enum descriptions do not map these legacy identifiers to current named groups or dimensions. The help page permits medium Dynamic Island scaling from Face ID large and large Dynamic Island scaling from Face ID large. Confirm actual set type, dimensions, delivery state and ASC preview/scaling; do not infer exact current-group mapping from the enum suffix alone. No authenticated upload/acceptance experiment was performed.

- [ ] Capture the selected build in use with fictional, non-sensitive reminder data; preview all required slots/locales in ASC. Keep a large-display set if desired, and verify medium-display coverage. No screenshots are in the baseline repo.
- [ ] Check the bundled icon and ASC rendering. A universal 1024×1024 `AppIcon.png` asset entry exists; this audit did not certify its appearance, alpha or archive output. [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons).
- [ ] Confirm listing name, subtitle, description, keywords, category, copyright/content rights, privacy/support URLs and accurate capability claims. Name/subtitle limits are 30 characters; description 4000; keywords 100 bytes. Check current localization fields. [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/), [platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/).

### Owner declarations: age, encryption, price, trader, accessibility

- [ ] Answer the current age questionnaire, including social-media, UGC, messaging, browsing, advertising and controls questions. Private self-authored reminders are not a public social feed, but the owner must review the release and generated regional ratings; **4+ is not pre-certified**. [Set rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).
- [ ] Confirm encryption classification for the app **and libraries**. `ITSAppUsesNonExemptEncryption=false` exists; HTTPS and CryptoKit hashing are present. This key means no encryption or only exempt encryption, not “answer No to every encryption question.” Use Apple's questionnaire and provide documents if needed. [Export overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance), [key semantics](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).
- [ ] Confirm **Free**, no IAP/subscriptions, selected storefronts and new-territory availability in ASC; decide Mac/Apple Vision Pro compatibility distribution too. A price schedule/availability object does not prove a zero price. [Pricing](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price), [availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store).
- [ ] Edmund must determine trader status from commercial activity, not individual enrollment or free price. Declare status even without EU distribution; EU traders must verify required public address/phone/email, payment details and certification. Never invent identity/contact details. [DSA guidance](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements).
- [ ] Audit VoiceOver, Larger Text, contrast and Reduce Motion on common tasks including sign-in, board editing and deletion. Labels/hints and reduce-motion handling exist, but device usability is untested here. Accessibility Nutrition Labels remain initially voluntary in Apple's current guidance; no mandatory date was verified. Publish only supported claims after testing. [Label overview and criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels).
- [ ] Confirm membership, agreements, signing/capabilities and ASC roles, then complete all human gates before Edmund authorizes submission. This work does not authorize production deployment or App Review submission.

## Read-only preflight audit (script unchanged)

At c131c41, `scripts/asc-preflight.sh` runs read-only ASC commands. A green report is **not** release approval:

- Version resolver falls back to the first ID even without an exact version/platform match.
- Screenshot check combines a 6.9-inch set flag with a global file count; empty required sets can pass. It does not establish current medium-display coverage, successful processing, dimensions or accuracy.
- Review checks only nonempty email/notes, not full contact details or working account access.
- Pricing can pass on availability alone; zero customer price is not enforced.
- It does not certify SDK/signing, icon, native QA, privacy, age, export or DSA declarations.

The coordinator owns a separate preflight fix PR. Its revised design deliberately returns UNKNOWN/nonzero for evidence the API cannot verify; require actual evidence and a manual release decision rather than blind attestations or forcing green. Re-audit that implementation when integrated; keep manual gates even after parser fixes.


## Release PR map and integration order

Coordinator plan as of **9 October 2026**; these twelve PRs are open, not shipped. Confirm current bases and checks in GitHub before integration. This map does not authorize merging, deployment or submission.

Start with [#54 — release build and web/MCP CI gates](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/54). The coordinator identified an existing persistence simulator-selector failure and a Node types dependency failure in hosted MCP CI; fixes belong in this CI foundation. Those workflow failures alone do not establish a feature-code failure. Feature branches are planned to stack on that foundation so native and hosted checks run with the corrected setup.

Then integrate/review in the coordinator's planned order:

1. [#50 — reject reminder mutations after sign-out](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/50).
2. [#51 — preserve reminder drafts when add fails](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/51).
3. [#53 — privacy manifest and data handling disclosures](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/53).
4. [#57 — revoked Apple credential handling and FIFO authentication gate](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/57); coordinator-reported ticket fix head `e05280d12459799e1010d2d4d18faa1a358c72b4`; final combined review/native validation remains open.
5. [#55 — account deletion cancellation and Apple revocation failure recovery](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/55), **verified GitHub base `release/apple-credential-revocation` (#57)**, verified GitHub head `8a6c10a4258880dcb3b7136145b7a5a962ef2cd4`, rebased onto #57 `e05280d12459799e1010d2d4d18faa1a358c72b4`. It captures a mandatory deletion intent before Apple authorization and validates it inside the shared gate before invocation, retaining cancellation and fallback handling; focused independent review is in progress.
6. [#60 — bound OAuth grant cleanup during account deletion](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/60), based on `release/ios-ci-gates` (#54).
7. [#52 — existing-account password login and secure reviewer provisioning guide](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/52), **verified GitHub base `release/apple-credential-revocation` (#57)**, verified GitHub head `33dbba5a2d359ff7301807b93fb83161cc6a84c5`, rebased onto #57 `e05280d12459799e1010d2d4d18faa1a358c72b4`. Password-session installation uses the shared FIFO gate. These base/head facts were read from GitHub on 9 October; recheck if either branch changes.
8. [#59 — submission preflight evidence checks](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/59).
9. [#56 — verify reminder writes before updating cache](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/56), based on #50.
10. [#61 — board publication privacy safety](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/61), **verified GitHub base `release/ios-reliability` (#50)**, head `997da4e7c1375e6c6e7f834e163a7ecc5e16a8e3`, based on #50 `8d94951`. Authoritative cached-board reads and a separate FIFO publication coordinator cover all indexing routes; focused independent review is in progress.

The coordinator reports the same-PR follow-ups resolved: #50 auth refresh/session rotation review clear at `8d94951`; #56 no production findings, with a one-line fixture correction at `b4aa011`; #59 both price-schedule reviews clear at `e26cec7`; #60 monotonic cleanup-deadline review clear at `ac90c947`; #57 round-four review clear for static analysis only. No additional PRs were created. Review clearance is scoped to those reviewed heads and is not native or physical-device verification.

Combined auth review subsequently found a #55 deletion race: account A can await Apple's authorization while B signs in, then a deletion invocation can use B's current bearer. The captured mandatory intent and #57-gated validation are now present in the verified #55 head above; focused review remains pending.

The coordinator locally integrated #55's verified update at `8766d87` and #61's publication fix at `26ecc3a`; their independent reviews are in progress. Earlier #57/#52 integration preserved #55's deletion response/notice body and auth-gate handling; #56 store integration differed only by the #57 read helper. The focused #57 S1→S2 ticket issue was confirmed and fixed at coordinator-reported head `e05280d12459799e1010d2d4d18faa1a358c72b4`, locally integrated. Same-user `lastSignInAt` is not unique: destructive checks now require the actual JWT `session_id`; missing IDs skip destructive checks and stable-ID token rotation is allowed. The change is limited to monitor/didSet binding, predicates and tests. Its 24 feature test methods were statically reviewed but not run here. #52/#55 feature-only rebases onto this fix are verified at the GitHub heads above; the coordinator reports byte-identical feature patches/range-diffs and matching integrated contents. #61 focused review remains in progress. Validate the final combined commit after these reviews and any updates.

The coordinator reports a successful native Release unit-test job for #51 and persistence job for an earlier #60 head **before** the monotonic-deadline change. These are scoped historical check results, not final combined-artifact validation. Final combined review/native validation, physical-device QA and signing/archive evidence remain open. Native run [37928404402](https://github.com/EdmundLimBoEn/lazy-mans-reminders/actions/runs/37928404402) remains queued and targets earlier combined commit `28c76d2`, excluding the new #55 intended-account fix, #61 board-publication fix and #57 session-ID ticket fix; it is not final release evidence. A final combined native run is planned after all updated heads and reviews are settled.

[#58 — this requirements/submission documentation](https://github.com/EdmundLimBoEn/lazy-mans-reminders/pull/58) remains standalone against `main`. When combining it with #57, preserve the exact **Apple credential revocation release gate (9 Oct 2026)** once in HUMANS.md's device QA checklist and remove the duplicate appended copy. Keep the separate server-side deletion gate. The reviewer guide links resolve when #52 is integrated.

Validate the combined reviewed commit after integration; earlier individual or local test results do not certify that final artifact. Signing/archive evidence, simulator CI results and physical-device tests remain distinct release gates. All operator prerequisites remain in [HUMANS.md](../HUMANS.md#app-store-submission).

Written by gpt-6.1-sol in T3 Code on behalf of Edmund
