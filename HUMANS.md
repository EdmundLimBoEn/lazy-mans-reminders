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
- [x] **Sign in with Apple (native / Supabase)** — Provider enabled via Management API with Client ID `systems.edmundlim.LazyMansReminders`. Native iOS Sign in with Apple should work once the App ID capability is on. **Web** Apple still needs a Services ID listed first in Client IDs + client secret (see [Supabase Apple docs](https://supabase.com/docs/guides/auth/social-login/auth-apple)); return URL `https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback`.
- [x] **Google sign-in (Supabase)** — Web OAuth client created in Google Cloud (`1066799131514-cpr7u3gq5r9hjnq375hee0g1b5be65ir…`); redirect + origins set; Google provider **enabled** in Supabase Auth with that client ID + secret (Mac handoff 7 Aug 2026).
- [x] **Deploy delete-account function** — Deployed to project `biwmsxbqrevtjwgsvsmu` (`supabase functions deploy delete-account`). JWT verification on; used by web + iOS account deletion.
- [x] **TestFlight build 1.0 (4)** — Uploaded with Xcode 27 beta 5 (`27A5237l`). Processing **VALID**. On Internal Testers (you) and Friends. TestFlight beta review is **WAITING_FOR_REVIEW** so email testers can install. Not submitted to the App Store. Beta 4 removed; `/Applications/Xcode-beta.app` is now beta 5. EdmundPurple theme kept.
- [ ] **Add your friend's email to TestFlight** — After Apple approves the TestFlight review (or immediately for you as Internal Testers):
  ```sh
  asc testflight testers add --app 6799138197 --email FRIEND@EMAIL --group Friends
  ```
- [ ] **Device test** — Open `ios/LazyMansReminders.xcodeproj`, sign both targets with team `DUU8J39BA7`, run on a physical iPhone (Apple / Google / magic link, complete-tap, push, lock-screen widgets, account deletion). No device build has been run yet.
- [ ] **Legal review** — Privacy / Terms / Support templates are live at `/privacy`, `/terms`, `/support` after web deploy. Have counsel review before monetized App Store submission. Contact email currently `hello@edmundlim.systems`.
- [ ] **Google web/iOS sign-in** — Provider is enabled. Confirm the Google Cloud **Web** client still has:
  - Authorized JavaScript origins: `https://lmr.edmundlim.systems`, `https://lazy-mans-reminders.pages.dev`, `http://localhost:5173`
  - Authorized redirect URI: `https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback`
  Then smoke-test Continue with Google on the live site (callback is `/auth/callback`).
- [ ] **Apple web sign-in** — Native iOS uses App ID `systems.edmundlim.LazyMansReminders`. **Web** Continue with Apple still needs a Services ID (e.g. `systems.edmundlim.LazyMansReminders.web`) listed **first** in Supabase Apple Client IDs, plus a client secret from an Apple Sign in with Apple key. Return URL `https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback`.
- [ ] **Agent MCP Worker** — From `mcp/`:
  ```sh
  cd mcp
  npm ci
  npx wrangler kv namespace create OAUTH_KV
  # paste the id into wrangler.jsonc kv_namespaces[0].id
  npx wrangler secret put SUPABASE_URL
  npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
  npx wrangler secret put SUPABASE_ANON_KEY
  npx wrangler deploy
  ```
  Then add a proxied CNAME `mcp.lmr` → the Worker route on `edmundlim.systems` (custom domain `mcp.lmr.edmundlim.systems`).
- [ ] **Push agent_tokens migration** — `supabase db push` so `agent_tokens`, `agent_token_clients`, `mint_agent_token`, `revoke_agent_token`, and `add_agent_reminder` exist in production. Redeploy `delete-account` after that.
