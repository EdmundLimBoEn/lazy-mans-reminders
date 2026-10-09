# Human actions

- [ ] **Move web to `lmr.sillyapps.co` (Oct 2026)** — Canonical web domain is now `https://lmr.sillyapps.co` (Pages project `lazy-mans-reminders`). Jeremy: proxied CNAME `lmr` → `lazy-mans-reminders.pages.dev` on `sillyapps.co`, add the custom domain on the Pages project, add the new Site URL and redirect URLs in Supabase Auth, deploy web then the MCP Worker, then add the 301 Single Redirect `lmr.edmundlim.systems` → `lmr.sillyapps.co`. Edmund: update the Google Web OAuth client's JavaScript origins and the App Store Connect privacy/support/marketing URLs. Keep the old-domain Supabase redirects and the redirect rule until no build in use sends `lmr.edmundlim.systems`. iOS in-app links and the magic-link redirect moved to `lmr.sillyapps.co` in #42 (ships with the next TestFlight build); builds already installed still use the old host. **8 Oct 2026:** the old host answers **302** (temporary), not 301. Switch the redirect rule to a 301 once you are happy with the move. Also confirm the hosted Supabase Auth redirect allow list has `https://lmr.sillyapps.co/auth/ios` (it is in `supabase/config.toml`, but prod auth config could not be read without a Management API token). Add it in the dashboard or via the Management API, never with `supabase config push`. The MCP host stays `lmr-mcp.edmundlim.systems`. Entries below that mention `lmr.edmundlim.systems` are history.

- [x] **Remove the extra Pages `Access-Control-Allow-Origin: *`** — Done 8 Oct 2026 (#46). It was the Cloudflare Pages default for static assets, not a dashboard rule: it also showed on `*.pages.dev`. `web/public/_headers` now detaches it (`! Access-Control-Allow-Origin` on `/*`); deployed and verified with curl on `lmr.sillyapps.co`. Nothing on that origin needs CORS (MCP/OAuth discovery lives on `lmr-mcp`).

- [x] **DNS for `lmr.edmundlim.systems`** — Proxied CNAME `lmr` → `lazy-mans-reminders.pages.dev` created via `cf dns records create`. Pages custom domain status is **active**. Site returns HTTP 200 (verified via public resolvers). Note: local Tailscale MagicDNS (`100.100.100.100`) may fail to resolve this name; `dig @1.1.1.1` / browsers using public DNS work.
- [x] **Apple Developer identifiers** — Bundle IDs already exist:
  - App `systems.edmundlim.LazyMansReminders` (`9H8ZY6WGY6`) with **Push Notifications** + **App Groups**
  - Widget `systems.edmundlim.LazyMansReminders.Widget` (`PBM95Q8YTQ`) with **App Groups**
  - Team `DUU8J39BA7`. Config.xcconfig points at `group.systems.edmundlim.LazyMansReminders`.
  - First signed Xcode build may still prompt to register the App Group identifier if Apple has not materialised the group container yet — accept the prompt if it appears.
  - Still needed: ~~enable **Sign in with Apple** on the app ID~~ **Done** (capability enabled on App ID `9H8ZY6WGY6`, Mac handoff 7 Aug 2026).
- [x] **APNs + webhook** —
  - `supabase/.env.functions` written (gitignored) from `AuthKey_YK47N2PQ54.p8` (team `DUU8J39BA7`, topic `systems.edmundlim.LazyMansReminders`).
  - `supabase secrets set --env-file supabase/.env.functions` applied (`APNS_*`, `WEBHOOK_SECRET`).
  - Webhook wired as trigger `send_reminder_push` (`AFTER INSERT OR UPDATE OR DELETE ON public.reminders`, checked 8 Oct 2026) → `notify_reminder_push()` → Edge Function, with secret in Vault (`lmr_webhook_secret`). Function auth verified: bad secret → 401, good secret → `{"sent":0}`.
  - **APNs key is being replaced (Oct 2026)** with a new APNs key enabled for **Sandbox & Production**, so debug and TestFlight/App Store builds share one key. When it exists, set the new `APNS_KEY_ID` / `APNS_PRIVATE_KEY` with `supabase secrets set` (never `supabase config push`), re-test push on a debug build and a TestFlight build, then revoke the old key.
  - If physical-device push fails with APNs auth errors, create a dedicated APNs Auth Key under Certificates, Identifiers & Profiles → Keys (enable APNs only), replace `APNS_KEY_ID` / `APNS_PRIVATE_KEY`, and re-run `supabase secrets set`.
- [x] **Sign in with Apple (native / Supabase)** — Provider enabled with App ID + Services ID (`systems.edmundlim.LazyMansReminders.web` first). Native + web Apple work; return URL `https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback`.
- [x] **Google sign-in (Supabase)** — Web OAuth client created in Google Cloud (`1066799131514-cpr7u3gq5r9hjnq375hee0g1b5be65ir…`); redirect + origins set; Google provider **enabled** in Supabase Auth with that client ID + secret (Mac handoff 7 Aug 2026).
- [x] **Deploy delete-account function** — Deployed to project `biwmsxbqrevtjwgsvsmu` (`supabase functions deploy delete-account`). Redeployed 26 Aug 2026 so deletion also wipes `lock_screen_prefs`. Redeployed 6 Oct 2026 so deletion revokes OAuth grants first and fails if that cleanup does not finish. JWT verification on; used by web + iOS account deletion.
- [x] **Apple token revocation implementation history (device/failure validation still open)** — Implemented in #38. `delete-account` v6 is live with the Apple secrets set (Supabase now lists the active function as version 7, updated 7 Oct 2026). Sign in with Apple key `4F6HNS5WW8` confirmed (team `DUU8J39BA7`, client `systems.edmundlim.LazyMansReminders`). iOS asks Apple for a fresh authorization code before deleting; the function exchanges it and calls Apple’s revoke endpoint. A revoke failure is logged as `apple_token_revoke` and does not block deletion. Do not put the `.p8` in git.
- [x] **Deploy web** — New legal pages, export, favicon, robots, and security.txt are live on `https://lmr.edmundlim.systems` (Wrangler device login, 27 Aug 2026). Confirm `/privacy` has no "launch template" copy. Redeployed 1 Sep 2026 from `main` (`a27de02`); `/auth/ios` was already in the production bundle. 8 Oct 2026: privacy policy update (#45, deployment `745d65a6`) and the CORS header removal (#46, deployment `62585816`) deployed to production `lmr.sillyapps.co` (`wrangler pages deploy dist --branch main`).
- [x] **Supabase iOS magic-link redirects** — Hosted Auth `uri_allow_list` now includes `https://lmr.edmundlim.systems/auth/ios` and `https://lazy-mans-reminders.pages.dev/auth/ios` (patched via Management API on project `biwmsxbqrevtjwgsvsmu`, 1 Sep 2026). Did not `supabase config push` the local stubs (that would disable Apple/Google).
- [x] **Xcode 27 beta builds retired** — The old internal-only builds 1.0 (4) and 1.0 (5) were made with Xcode 27 beta, which App Store Connect rejects for external testing. Do not install them. TestFlight builds now come only from `.github/workflows/ios-testflight.yml` (hosted `macos-latest`, stable Xcode).
- [ ] **TestFlight Test Information** — Paste the Beta App Description, Feedback Email, URLs, What to Test, and Beta App Review notes from [docs/app-store.md → TestFlight beta](docs/app-store.md#testflight-beta) before inviting external testers.
- [ ] **GitHub Actions TestFlight secrets (Jeremy)** — Set repository secrets, then re-run **iOS TestFlight** (`workflow_dispatch` or a push under `ios/`). Do not commit values, `.p8` / `.p12` files, or `ios/Config.xcconfig`.
  - `ASC_KEY_ID` — App Store Connect API Key ID
  - `ASC_ISSUER_ID` — App Store Connect Issuer ID
  - `ASC_PRIVATE_KEY_B64` — `base64` of the `AuthKey_*.p8` (App Store Connect API key, not the APNs key)
  - `APPSTORE_CERTIFICATES_FILE_BASE64` — `base64` of the Apple Distribution `.p12`
  - `APPSTORE_CERTIFICATES_PASSWORD` — password for that `.p12`
  App id `6799138197` and team `DUU8J39BA7` are hardcoded. The API key needs access to create App Store provisioning profiles and upload builds.
- [ ] **Add your friend's email to TestFlight** — After Apple approves the TestFlight review (or immediately for you as Internal Testers):
  ```sh
  asc testflight testers add --app 6799138197 --email FRIEND@EMAIL --group Friends
  ```
- [ ] **Device test** — Open `ios/LazyMansReminders.xcodeproj`, sign both targets with team `DUU8J39BA7`, run on a physical iPhone (Apple / Google / magic link, complete-tap, push, lock-screen widgets, account deletion). This checklist does not establish physical-device validation of the selected release build.
- [ ] **Expanded island spacing** — After TestFlight processing finishes for the 24 Sep 2026 upload ([run 35936302830](https://github.com/EdmundLimBoEn/lazy-mans-reminders/actions/runs/35936302830)), install that build and press-and-hold the island. The last reminder line should sit above the bottom curve.
- [ ] **Siri / App Intents (iOS 26+, Apple Intelligence on iOS 27)** — After a signed-in launch on a physical iPhone, confirm:
  - “Hey Siri, list reminders in Lazy Man's Reminders”
  - “Hey Siri, add a reminder in Lazy Man's Reminders” / “remind me to …” (in this app)
  - “Hey Siri, mark this as done” (with the board on screen) or “complete *milk* in Lazy Man's Reminders”
  - Spotlight shows an active reminder by its text. Unsigned-in, Siri should ask you to sign in.
- [ ] **Live Activity persistence (2026-08-28)** — Code is in the repo. Migration `202608280001_live_activity_tokens` applied to `biwmsxbqrevtjwgsvsmu` via `supabase db push --linked` (28 Aug 2026). Still needs:
  - [x] Apply migration `202608280001_live_activity_tokens`.
  - [x] Redeploy `send-reminder-push` with JWT verification off (24 Sep 2026, includes the quiet Live Activity refresh).
  - [x] Push trigger fires on `INSERT`, `UPDATE`, and `DELETE` for `public.reminders`: `send_reminder_push` is `AFTER INSERT OR DELETE OR UPDATE` (checked in `pg_trigger`, 8 Oct 2026). Completing or deleting the last reminder is what ends the Lock Screen banner.
  - [x] Confirmed `live-activity-refresh` is active every 15 minutes (26 Sep 2026); recent requests returned HTTP 200. This is required for renewal while the app is closed.
  - After installing the new build, open the app once while signed in (Settings → Live Activities on for this app). That uploads the push-to-start token. Later reminder notifications should raise the Lock Screen banner without opening the app.
  - Physical iPhone test: add a reminder from the web with the app killed; confirm the Lock Screen banner appears. Complete every reminder; confirm it goes away. Leave one reminder overnight and confirm the banner is still there after the scheduled 15-minute refresh.

- [ ] **Legal review** — Privacy / Terms / Support are live at `/privacy`, `/terms`, `/support`. Counsel review is optional. Contact: `hello@edmundlim.systems`.
- [ ] **App Store Connect fields** — Copy name, subtitle, description, nutrition labels, and review notes from `docs/app-store.md`. Capture the current required screenshot groups from that file. Full submission evidence checklist is **App Store submission** below.
- [ ] **Google web/iOS sign-in** — Provider is enabled. Confirm the Google Cloud **Web** client still has:
  - Authorized JavaScript origins: `https://lmr.edmundlim.systems`, `https://lazy-mans-reminders.pages.dev`, `http://localhost:5173`
  - Authorized redirect URI: `https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback`
  Then smoke-test Continue with Google on the live site (callback is `/auth/callback`).
  From Grok Bot, add `https://lmr-mcp.edmundlim.systems/mcp` without a bearer header. Complete Google sign-in, tap **Allow**, and confirm Grok returns from `https://grok.com/connectors-oauth-exchange-code/`.
- [x] **Apple web sign-in** — Services ID `systems.edmundlim.LazyMansReminders.web` first in Client IDs; Apple client secret set; Continue with Apple works after Services ID Configure + Return URL.
- [x] **Agent MCP Worker** — Deployed `lazy-mans-reminders-mcp` with OAUTH_KV + secrets. Custom domain `lmr-mcp.edmundlim.systems` (Universal SSL; not `mcp.lmr…` which needs Advanced Certs). On 6 Oct 2026 `workers_dev` was turned off; `https://lazy-mans-reminders-mcp.edmundlim.workers.dev/` returns 404. Use `https://lmr-mcp.edmundlim.systems/mcp`.
- [x] **Push agent_tokens migration** — `202608080002_lock_screen_prefs` + `202608260001_agent_tokens` pushed; `delete-account` redeployed.
- [x] **Resend SMTP** — Custom SMTP `smtp.resend.com` for `noreply-lmr@auth.edmundlim.systems`; email rate limit raised above built-in 2/hour.

- [ ] **Live Activity renewal handoff (26 Sep 2026)** — Backend renewal now retains the old banner until the phone uploads the replacement token. Open the signed-in app once, leave an active reminder overnight with the app in the background, and confirm the board remains visible beyond eight hours. Brief overlap during renewal can last until the next 15-minute refresh. Then complete the board and confirm both banners disappear. No new iOS build is required for this backend change.

- [ ] **Early disappearance on development build (26 Sep 2026)** — User reports disappearance after a couple of hours, restored by reopening. Scheduled refreshes now send low-priority, non-alerting updates every 15 minutes even before seven hours; an invalid activity token triggers replacement, while network/auth failures do not create duplicates. A direct update to the development token was accepted by APNs. Leave the app closed during the next disappearance and check whether the scheduled refresh restores the board. Apple accepting a push does not prove that iOS displayed it; the underlying removal cause remains unverified.

- [ ] **Persistence build and release gate (3 Oct 2026)** — [Signed build uploaded to App Store Connect](https://github.com/EdmundLimBoEn/lazy-mans-reminders/actions/runs/37137028085); processing/tester availability is not yet verified. Install the new build containing the background token registrar, Background App Refresh, and Home Screen Board widgets. Follow [the persistence test checklist and November release gates](docs/live-activity-persistence.md). Primary test: leave the app normally backgrounded for 24 hours, including the 7–9h renewal window; test force-quit separately. Record whether the widget and Live Activity remain, and whether recovery happens before reopening. Target release by 30 November, conditional on the seven-day TestFlight soak and remaining release checks.

## App Store submission

Updated 9 October 2026. See [official Apple requirements and baseline gaps](docs/apple-release-requirements.md), [draft submission copy](docs/app-store.md), and [native handoff](MAC_HANDOFF.md). Earlier 27 October / 30 November dates are internal targets, not Apple deadlines. All gates below apply to the selected reviewed release commit and processed build, not an older upload. This docs audit ran on Linux without Xcode or physical-device QA.

### Build and configuration

- [ ] Confirm Developer Program membership, agreements, authorized ASC roles, signing identity/profiles, app/extension IDs, App Groups, Sign in with Apple and production APNs entitlements. Verify ownership/contact rather than inventing identities.
- [ ] Prepare authorized build secrets locally/in CI (existing secret list above), use release Xcode 26+ / iOS 26 SDK+ and record artifact SDK, deployment target, build number and commit. iOS 17 target already exceeds the effective iOS 13 floor. Do not reuse retired beta builds 4/5 or deploy/upload unreviewed PRs.
- [ ] Run native simulator tests/archive validation on a Mac or hosted macOS workflow, inspect embedded extension, resolved packages, privacy manifests and aggregate Xcode privacy report; attach the correctly processed build only after approval.
- [ ] Verify production backend version/config for the reviewed release, Auth provider/redirect configuration and Sandbox & Production APNs key readiness. Deployment history above does not prove selected-build end-to-end behavior. Coordinate any production change separately; never bulk-delete live data or rewrite existing migrations.

### Reviewer access and device QA

- [ ] After the reviewer-access PR is integrated, follow [secure provisioning](docs/reviewer-access.md): provision a stable confirmed **synthetic existing account**, store real credentials privately, test fresh-install email/password reviewer login and full backend access without Edmund's inbox, then enter credentials in ASC account fields. No working review account is asserted by these docs. Apple self-signup alone is not a verified substitute. If using Apple's legal/security demo exception, obtain prior approval.
- [ ] Populate App Review and external TestFlight review contact first/last name, reachable phone/email, actual credentials/authentication instructions and notes. Keep access active throughout review; use a second disposable account for deletion tests.
- [ ] Install the exact processed TestFlight artifact on a physical iPhone; record device/OS/build/date/results. Test Apple, Google and email magic link; existing-account password login when integrated; cold launch, expired sessions and poor connectivity.
- [ ] Add/complete/delete and other supported board actions, sync with web, refresh and capacity; check offline/error recovery.
- [ ] Deny notifications first, confirm board usability and Settings recovery; allow on a second pass and verify a web-created reminder alerts. Check separate Live Activities settings and no repeated authorization prompts.
- [ ] Verify activity start/update/renew/end, widget consistency, user dismissal and settings disabling. Follow [persistence QA](docs/live-activity-persistence.md), including 24-hour background observation/7–9h renewal and the project's soak. Test force-quit separately; record actual behavior instead of APNs success or guaranteed indefinite persistence.
- [ ] Verify Apple/Google/email deletion on exact disposable test accounts **with consent**: Cancel preserves account, full deletion removes owned data and agent grants, sign-out clears app/widget/activity/session state, Apple revocation completes or documented manual fallback is shown. Cover web and native cancellation, missing token/config, network failure. The separate Apple credential revocation gate below covers identity-state handling. Privacy/deletion/credential-state changes have separate PRs; historical implementation checkmarks do not close these tests.
- [ ] Check Account → Download My Data, signed-in web export, feedback and support contact. Confirm retention/backups explanation matches operation.
- [ ] Check no stale private data after sign-out, account switching or deletion.

- [ ] **Apple credential revocation release gate (9 Oct 2026)** — Run the macOS iOS simulator CI tests, including `AppleCredentialMonitorTests`, then use a disposable Apple-linked account on a physical iPhone. Revoke the app's Apple access while it is foregrounded and while backgrounded; after notification/foreground, confirm the app requires sign-in and the App Group board, widget and Live Activity clear. Cold-launch with revoked access and repeat with a non-Apple account and temporary offline connectivity; offline errors must preserve its session. This Linux change has no Xcode or physical-device verification. Follow [Apple TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple); server-side account deletion/revocation is a separate release requirement.

- [ ] Test advertised Siri/Shortcuts phrases on the selected artifact/OS; do not advertise iOS 27 schema features merely because source exists.
- [ ] Audit VoiceOver, Larger Text, contrast and Reduce Motion on sign-in, board and deletion. Accessibility labels are initially voluntary under current Apple guidance; claim support only after the common-task criteria pass.

### Assets, public pages and metadata

- [ ] Capture real app-in-use screenshots with fictional non-sensitive reminders on the tested build; verify **current required display groups** and scaling in ASC per [Apple specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). Medium Dynamic Island portrait accepts 1179×2556 / 1206×2622; large-display captures can supplement it. Baseline is iPhone-only; no iPad set unless support changes. Opaque JPEG/PNG; confirm successful processing and previews in every submitted localization. No login-only set under repo convention.
- [ ] Validate archived 1024×1024 icon/asset appearance, opacity and ASC product-page rendering; a source icon entry is not acceptance proof.
- [ ] Apply and confirm tested listing name/subtitle/description/keywords, category, copyright/content rights, privacy/support/marketing URLs and build-specific review notes from [submission notes](docs/app-store.md). Remove placeholders and untested Siri/indefinite-persistence claims.
- [ ] Confirm privacy/support/terms/marketing/auth routes render and navigation works in a normal browser and on the device outside the home network; confirm support inbox monitored. Coordinator's 9 October HTTP check: privacy on canonical and Pages hosts returns 200 with Mozilla/5.0 User-Agent, default Python User-Agent gets 403. This is not evidence of a universally down domain. Browser rendering/UI QA remains open because T3 browser automation was blocked by host AppArmor.
- [ ] Complete TestFlight Test Information before external invitations; beta review and App Store review are separate approvals.

### Owner declarations and final approval

- [ ] Audit actual Supabase provider profile fields (including possible name), logs/diagnostics, reminder content, identities and push tokens; reconcile policy, ASC labels and manifest independently. Confirm collection/linkage/purposes/tracking and optional beta feedback disclosure criteria. Do not exclude Name/Diagnostics solely because the baseline manifest omits them.
- [ ] Verify required-reason API/SDK changes in the final archive: App Group and app-only UserDefaults use, all other required categories, integrated manifests and signatures where required for listed binary SDKs. Audit protected API use/purpose strings; do not request unused permissions.
- [ ] Answer the current age questionnaire, including social-media questions required since September 2026, and confirm resulting global/regional ratings. Do not assume 4+ from an old draft.
- [ ] Confirm encryption classification including dependencies using Apple's current questionnaire; `ITSAppUsesNonExemptEncryption=false` means no encryption or only exempt encryption, not No to every question. Provide export documentation if required.
- [ ] Confirm zero **Free** price, no IAP/subscriptions, selected storefronts/new-territory availability. Decide compatible Mac/Apple Vision Pro distribution and content-rights declarations.
- [ ] Edmund: determine **DSA trader status** from actual commercial activity. Individual/free does not automatically mean trader or non-trader. Declare status; if EU trader, verify public address/phone/email and other required details/certification. Do not invent legal data or automatically choose status.
- [ ] Recheck current Apple requirements immediately before upload/submission. Run read-only preflight after the separate script PR is integrated; inspect results and remaining manual gates. The revised preflight deliberately reports UNKNOWN and exits nonzero for evidence the API cannot verify; do not force green or invent attestations. Resolve each item from actual release evidence and an explicit manual release decision. Preflight is not Apple approval or a substitute for QA.
- [ ] Edmund: review all evidence, select release mode/date, and explicitly authorize App Review submission when ready. **Do not submit, merge these PRs or deploy unreviewed production changes as part of this task.**

Written by gpt-6.1-sol in T3 Code on behalf of Edmund
