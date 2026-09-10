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
- [x] **Rebuild iOS for email sign-in** — TestFlight **1.0 (5)** uploaded 1 Sep 2026 with Xcode 27 beta 5 (`27A5237l`). Processing **VALID**. Added to Internal Testers and Friends. Binary contains `https://lmr.edmundlim.systems/auth/ios`. Install 5 from TestFlight (not 4, and not the accidental 1.0 (1) from the first upload). Then request a **new** email link on the phone.
- [ ] **Add your friend's email to TestFlight** — After Apple approves the TestFlight review (or immediately for you as Internal Testers):
  ```sh
  asc testflight testers add --app 6799138197 --email FRIEND@EMAIL --group Friends
  ```
- [ ] **Device test** — Open `ios/LazyMansReminders.xcodeproj`, sign both targets with team `DUU8J39BA7`, run on a physical iPhone (Apple / Google / magic link, complete-tap, push, lock-screen widgets, account deletion). No device build has been run yet.
- [ ] **Siri / App Intents (iOS 26+, Apple Intelligence on iOS 27)** — After a signed-in launch on a physical iPhone, confirm:
  - “Hey Siri, list reminders in Lazy Man's Reminders”
  - “Hey Siri, add a reminder in Lazy Man's Reminders” / “remind me to …” (in this app)
  - “Hey Siri, mark this as done” (with the board on screen) or “complete *milk* in Lazy Man's Reminders”
  - Spotlight shows an active reminder by its text. Unsigned-in, Siri should ask you to sign in.
- [x] **Live Activity renewal backend (2026-09-08)** — Deployed the current `send-reminder-push` and migration `202609080001_live_activity_refresh`. Production previously ran the pre-Live-Activity function and had no scheduler. Reminder INSERT, UPDATE, and DELETE now invoke the function. `pg_cron` refreshes every 15 minutes and activities become eligible for replacement after seven hours. Token registration records missing start times without resetting age during token rotation. Verified the database-to-function path returned HTTP 200 with `{"sent":2,"failed":0,"retryable":0}`. All 38 server tests and transactional database checks passed.
- [x] **Live Activity token payload (2026-09-10)**. Deployed `send-reminder-push` version 5 with `input-push-token: 1` on remote starts. All 39 server tests pass. The production device row had no Live Activity tokens even though the scheduler was running successfully. The iOS correction moves token registration out of SwiftUI into the application lifecycle and excludes ended activities from local updates.
- [ ] **Live Activity device verification**. The corrected development build is installed on the connected iPhone. Unlock it, open the signed-in app, and verify a cold background start uploads its update token. Then leave one reminder active beyond eight hours and confirm the Lock Screen banner renews. The connected iPhone was locked during debugging on 10 September. APNs acceptance and simulator tests do not prove overnight visibility.

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
