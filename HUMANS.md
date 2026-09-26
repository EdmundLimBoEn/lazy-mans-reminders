# Human actions

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
  - INSERT webhook wired as trigger `send_reminder_push` → `notify_reminder_push()` → Edge Function, with secret in Vault (`lmr_webhook_secret`). Function auth verified: bad secret → 401, good secret → `{"sent":0}`.
  - If physical-device push fails with APNs auth errors, create a dedicated APNs Auth Key under Certificates, Identifiers & Profiles → Keys (enable APNs only), replace `APNS_KEY_ID` / `APNS_PRIVATE_KEY`, and re-run `supabase secrets set`.
- [x] **Sign in with Apple (native / Supabase)** — Provider enabled with App ID + Services ID (`systems.edmundlim.LazyMansReminders.web` first). Native + web Apple work; return URL `https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback`.
- [x] **Google sign-in (Supabase)** — Web OAuth client created in Google Cloud (`1066799131514-cpr7u3gq5r9hjnq375hee0g1b5be65ir…`); redirect + origins set; Google provider **enabled** in Supabase Auth with that client ID + secret (Mac handoff 7 Aug 2026).
- [x] **Deploy delete-account function** — Deployed to project `biwmsxbqrevtjwgsvsmu` (`supabase functions deploy delete-account`). Redeployed 26 Aug 2026 so deletion also wipes `lock_screen_prefs`. JWT verification on; used by web + iOS account deletion.
- [x] **TestFlight build 1.0 (4)** — Uploaded with Xcode 27 beta 5 (`27A5237l`). Processing **VALID**. On Internal Testers (you) and Friends. TestFlight beta review is **WAITING_FOR_REVIEW** so email testers can install. Not submitted to the App Store. Beta 4 removed; `/Applications/Xcode-beta.app` is now beta 5. EdmundPurple theme kept.
- [x] **Deploy web** — New legal pages, export, favicon, robots, and security.txt are live on `https://lmr.edmundlim.systems` (Wrangler device login, 27 Aug 2026). Confirm `/privacy` has no "launch template" copy. Redeployed 1 Sep 2026 from `main` (`a27de02`); `/auth/ios` was already in the production bundle.
- [x] **Supabase iOS magic-link redirects** — Hosted Auth `uri_allow_list` now includes `https://lmr.edmundlim.systems/auth/ios` and `https://lazy-mans-reminders.pages.dev/auth/ios` (patched via Management API on project `biwmsxbqrevtjwgsvsmu`, 1 Sep 2026). Did not `supabase config push` the local stubs (that would disable Apple/Google).
- [x] **Rebuild iOS for email sign-in** — TestFlight **1.0 (5)** uploaded 1 Sep 2026 with Xcode 27 beta 5 (`27A5237l`). Processing **VALID**. Added to Internal Testers and Friends. Binary contains `https://lmr.edmundlim.systems/auth/ios`. Install 5 from TestFlight (not 4, and not the accidental 1.0 (1) from the first upload). Then request a **new** email link on the phone. Build 5 is internal-only: App Store Connect rejects Xcode 27 beta (`Unsupported SDK or Xcode version`). New TestFlight builds go through `.github/workflows/ios-testflight.yml` on hosted `macos-latest` (stable Xcode). Next build number is **6**.
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
- [ ] **Device test** — Open `ios/LazyMansReminders.xcodeproj`, sign both targets with team `DUU8J39BA7`, run on a physical iPhone (Apple / Google / magic link, complete-tap, push, lock-screen widgets, account deletion). No device build has been run yet.
- [ ] **Expanded island spacing** — After TestFlight processing finishes for the 24 Sep 2026 upload ([run 35936302830](https://github.com/EdmundLimBoEn/lazy-mans-reminders/actions/runs/35936302830)), install that build and press-and-hold the island. The last reminder line should sit above the bottom curve.
- [ ] **Siri / App Intents (iOS 26+, Apple Intelligence on iOS 27)** — After a signed-in launch on a physical iPhone, confirm:
  - “Hey Siri, list reminders in Lazy Man's Reminders”
  - “Hey Siri, add a reminder in Lazy Man's Reminders” / “remind me to …” (in this app)
  - “Hey Siri, mark this as done” (with the board on screen) or “complete *milk* in Lazy Man's Reminders”
  - Spotlight shows an active reminder by its text. Unsigned-in, Siri should ask you to sign in.
- [ ] **Live Activity persistence (2026-08-28)** — Code is in the repo. Migration `202608280001_live_activity_tokens` applied to `biwmsxbqrevtjwgsvsmu` via `supabase db push --linked` (28 Aug 2026). Still needs:
  - [x] Apply migration `202608280001_live_activity_tokens`.
  - [x] Redeploy `send-reminder-push` with JWT verification off (24 Sep 2026, includes the quiet Live Activity refresh).
  - In Supabase **Database → Webhooks**, edit `send-reminder-push` so it fires on `INSERT`, `UPDATE`, and `DELETE` for `public.reminders` (same URL and `x-webhook-secret`). Completing or deleting the last reminder is what ends the Lock Screen banner.
  - [x] Confirmed `live-activity-refresh` is active every 15 minutes (26 Sep 2026); recent requests returned HTTP 200. This is required for renewal while the app is closed.
  - After installing the new build, open the app once while signed in (Settings → Live Activities on for this app). That uploads the push-to-start token. Later reminder notifications should raise the Lock Screen banner without opening the app.
  - Physical iPhone test: add a reminder from the web with the app killed; confirm the Lock Screen banner appears. Complete every reminder; confirm it goes away. Leave one reminder overnight and confirm the banner is still there after the hourly refresh.

- [ ] **Legal review** — Privacy / Terms / Support are live at `/privacy`, `/terms`, `/support`. Counsel review is optional. Contact: `hello@edmundlim.systems`.
- [ ] **App Store Connect fields** — Copy nutrition labels and review notes from `docs/app-store.md`. Attach screenshots from a physical device.
- [ ] **Google web/iOS sign-in** — Provider is enabled. Confirm the Google Cloud **Web** client still has:
  - Authorized JavaScript origins: `https://lmr.edmundlim.systems`, `https://lazy-mans-reminders.pages.dev`, `http://localhost:5173`
  - Authorized redirect URI: `https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback`
  Then smoke-test Continue with Google on the live site (callback is `/auth/callback`).
  From Grok Bot, add `https://lmr-mcp.edmundlim.systems/mcp` without a bearer header. Complete Google sign-in, tap **Allow**, and confirm Grok returns from `https://grok.com/connectors-oauth-exchange-code/`.
- [x] **Apple web sign-in** — Services ID `systems.edmundlim.LazyMansReminders.web` first in Client IDs; Apple client secret set; Continue with Apple works after Services ID Configure + Return URL.
- [x] **Agent MCP Worker** — Deployed `lazy-mans-reminders-mcp` with OAUTH_KV + secrets. Custom domain `lmr-mcp.edmundlim.systems` (Universal SSL; not `mcp.lmr…` which needs Advanced Certs). Fallback: `https://lazy-mans-reminders-mcp.edmundlim.workers.dev/mcp`.
- [x] **Push agent_tokens migration** — `202608080002_lock_screen_prefs` + `202608260001_agent_tokens` pushed; `delete-account` redeployed.
- [x] **Resend SMTP** — Custom SMTP `smtp.resend.com` for `noreply-lmr@auth.edmundlim.systems`; email rate limit raised above built-in 2/hour.

- [ ] **Live Activity renewal handoff (26 Sep 2026)** — Backend renewal now retains the old banner until the phone uploads the replacement token. Open the signed-in app once, leave an active reminder overnight with the app in the background, and confirm the board remains visible beyond eight hours. Brief overlap during renewal can last until the next 15-minute refresh. Then complete the board and confirm both banners disappear. No new iOS build is required for this backend change.

- [ ] **Early disappearance on development build (26 Sep 2026)** — User reports disappearance after a couple of hours, restored by reopening. Scheduled refreshes now send low-priority, non-alerting updates every 15 minutes even before seven hours; an invalid activity token triggers replacement, while network/auth failures do not create duplicates. A direct update to the development token was accepted by APNs. Leave the app closed during the next disappearance and check whether the scheduled refresh restores the board. Apple accepting a push does not prove that iOS displayed it; the underlying removal cause remains unverified.
