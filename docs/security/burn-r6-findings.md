# Burn r6 findings (not changed)

Review of Notepad / Lazy Man's Reminders on `origin/main` `4dc0f912`, after burns r1–r5. Hosted project `biwmsxbqrevtjwgsvsmu`.

Small, test-backed repo fixes from this pass land in their own PRs. This file is only what was left alone: deploy-time work, dashboard toggles, dependency majors, or behavior that would change auth or API error shapes.

## Production schema is behind the repo

`list_migrations` on the hosted database stops at `202610220003_reminder_quotas`. Public tables in production: `reminders`, `device_tokens`, `lock_screen_prefs`, `agent_tokens`, `routine_reminders`. All five have RLS and FORCE RLS.

The repo has later migrations that create `live_activity_start_leases`, `device_delivery_slots`, `reminder_push_jobs`, `user_write_budgets`, retention/lock tweaks, and `normalize_legacy_reminder_text`. Those objects are not in production.

Do not `supabase db push` the whole tail as a security hotfix. `normalize_legacy_reminder_text` rewrites reminder text. Push jobs and leases change how APNs delivery runs. Apply with a planned deploy, in version order, after reading each file.

Until that push happens, additive grant revokes in the repo also do not affect production.

## `REVOKE FROM PUBLIC` does not drop `anon` (production until db push)

Supabase default privileges grant `EXECUTE` / `ALL` to `anon` as a **role** grant. `REVOKE … FROM PUBLIC` leaves `anon=X` in `proacl`. That is why #47 had to name `anon` on `mint_agent_token` / `revoke_agent_token`.

Production still has `anon=X` on `delete_old_completed_reminders`, `next_routine_run`, `prepare_routine_schedule`, `set_completed_at`, `set_updated_at`, `track_live_activity_start`, and `ALL` on `agent_token_clients`. Those functions are `SECURITY INVOKER`; RLS on `reminders` would still deny anon DML. The token view is `security_invoker` over a revoked table, so unauthenticated `SELECT` already fails. That is defense in depth, not a live hash leak.

`track_live_activity_start` is created in `202609080001_live_activity_refresh`, which the focused CI migration list does not load (vault / pg_net / cron). A revoke for it would fail that job, so it stays a production leftover until a full `db push` includes a `REVOKE … FROM public, anon` that runs after that migration.

Follow-up repo migrations revoke those leftovers from `public, anon`. They do nothing in production until `supabase db push`. Later unapplied migrations that only `REVOKE FROM PUBLIC` would not have cleared `anon` by themselves.

User tables `reminders`, `device_tokens`, and `lock_screen_prefs` still have default `ALL` for `anon`. Policies are `TO authenticated` plus FORCE RLS, so anon DML is denied. Revoking table grants would change PostgREST from an RLS denial to a permission error. Left as-is.

## `delete-account` CORS `*`

`supabase/functions/delete-account/handler.ts` sends `Access-Control-Allow-Origin: *` and does not set `Access-Control-Allow-Credentials`. `verify_jwt` is true and the handler still requires a Bearer user JWT, so a foreign origin cannot use the user’s cookies. Tightening to the web origins would still need an edge-function redeploy and a check that iOS sends `Origin`. Not changed here.

## `send-reminder-push` still buffers JSON after the webhook secret

Once `x-webhook-secret` matches (constant-time hash compare), `request.json()` has no byte cap. Database webhooks send small payloads. A leaked `WEBHOOK_SECRET` could stall the function with a large body. Capping it needs an edge-function redeploy. Not changed here.

## Legacy webhook bodies can still select devices

With a valid webhook secret, a body that is not `{job_id}` can still load devices for `record.user_id` or run `{type:"live_activity_refresh"}` across every Live Activity token. Production dispatch sends `{job_id}` and reloads tokens from the database; alert text is not taken from the webhook. Closing the legacy branch changes who can push: the README still documents a raw Database Webhook, and tests post a raw refresh. Not changed here.

## Live Activity token columns have no upper bound in the database

`push_to_start_token`, `activity_push_token`, and `retiring_activity_push_token` allow `^[0-9A-Fa-f]{64,}$`. The sender refuses anything outside `^[0-9a-f]{64,512}$` before building an APNs URL, so this is not SSRF. Capping the column is a data migration. Not changed here.

## `APPLE_CLIENT_ID` and `MCP_GRANT_CLEANUP_URL` are deploy-time

Delete-account revocation uses env `APPLE_CLIENT_ID` as the Apple audience. If that secret is the Services ID while native codes are issued for the bundle id (or the reverse), native revoke fails closed and deletion still succeeds. `MCP_GRANT_CLEANUP_URL` is fetched with the user JWT and has no host allowlist (default `https://np-mcp.sillyapps.co/account/grants/cleanup`). Confirm both secrets at deploy time. Not changed here.

## GHSA-jm63 (`@modelcontextprotocol/server` 2.0.0)

Affected versions are 2.0.0–2.2.0 (shared transport / shared `McpServer`). This worker calls `createMcpHandler(() => createServer(session, env))`, a per-request factory, which the advisory marks as **not affected**.

A bump to 2.3.0 is blocked by `agents@^0.21.0` pinning `@modelcontextprotocol/server` 2.0.0. That is a coordinated `agents` upgrade plus a Worker redeploy, not a patch.

## zod 4.4.3 (GHSA-mrhx-c7xc-m3w5)

`mcp/package-lock.json` has zod 4.4.3. GitHub still lists `<4.6.6` as affected; CVE-2023-54404 was rejected. MCP JSON bodies are already capped at 16 KiB. Treat as scanner noise unless GitHub withdraws the advisory. A bump is optional and needs a Worker redeploy.

## Leaked password protection is off

Advisor `auth_leaked_password_protection`: HaveIBeenPwned checks are disabled on hosted Auth. Enable it in the dashboard (https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). No repo flag for this.

## `/auth/ios` still holds the original URL

The handoff page builds `lazymansreminders://auth/callback` from the current `window.location`. Implicit tokens are no longer copied onto that app URL. The HTTPS document (and history) can still contain `access_token` / `refresh_token` if GoTrue put them in the hash.

`history.replaceState` after reading the URL would make a refresh look like an incomplete link. Left as an auth-behavior change.

## `mint_agent_token` / `revoke_agent_token` advisor 0029

`authenticated_security_definer_function_executable` is expected. Both RPCs are `SECURITY DEFINER`, `EXECUTE` is authenticated-only after #47, and they bind to `auth.uid()`. Do not revoke authenticated.

## Signup and MFA

`supabase/config.toml` has `enable_signup = true`. TOTP enroll/verify are enabled; they are not required. Product choice, not a code bug.

## Official GitHub Actions stay floating

`actions/checkout@v4` and `actions/setup-node@v4` are unpinned. Third-party actions in this repo are SHA-pinned. Same residual as #79. Not redone.

## TestFlight installs unpinned `asc` and Homebrew `xcodegen` next to signing secrets

`.github/workflows/ios-testflight.yml` puts `ASC_PRIVATE_KEY_B64` and the distribution `.p12` password in the **job** environment. `rudrankriyam/setup-asc` is SHA-pinned, but the step does not pass `version` or `sha`, so the action downloads `rudrankriyam/App-Store-Connect-CLI` `releases/latest` and checks it against that release’s own checksum. `brew install xcodegen` in the same job is also unpinned.

`ASC_NO_UPDATE=1` only stops the binary from self-updating after install. A new or compromised `latest` release would still see the API key and the cert. Pinning which `asc` version (and whether to checksum a Homebrew bottle) is a deploy-time choice for the signing job. Not changed here. The other iOS workflows install `xcodegen` the same way but do not hold those secrets.

## Dev-only npm advisories

- Vitest 3.2.7 pulls tinypool 1.x (`GHSA-5gmw-xhrv-c9v3`, `GHSA-85c8-ppgw-ccpr`). There is no 1.x patch; Vitest 4 is a major of the test runner.
- Vite `<=7.3.6` (`GHSA-9jrq-w75r-8gcw`) is the custom `middlewareMode` / `transformIndexHtml` case. This app is a normal SPA. 7.3.7 is a patch if you want a clean audit.
- `web/package.json` already overrides `undici` to `^7.29.0`.

None of these ship in the Pages or Worker bundles except via the Vite build toolchain.

## MCP `/mcp` CORS `*`

`createMcpHandler` is called with `corsOptions: { origin: '*' }` and `allowedOriginHostnames: '*'`. The OAuth consent/JSON helpers already allowlist `WEB_ORIGINS`. The wildcard is on the JSON-RPC route for non-browser hosts. Changing it can break those hosts and needs a Worker redeploy.

## XSS / open redirects (re-checked, no extra change)

No `dangerouslySetInnerHTML` / `innerHTML`. Pages CSP is `script-src 'self'`; Pages `Access-Control-Allow-Origin` is stripped in `_headers`. `safeReturnPath` still rejects `https:`, `//`, backslash, and encoded slash. `/auth/ios` renders GoTrue `error_description` as React text (escaped). `isSafeOauthRedirect` still allows custom schemes after the `javascript:` / `data:` denylist; an `intent://` URL with a script fallback was not shown to execute in this origin, so it was left as-is.

## Prior burns not repeated

PKCE (`detectSessionInUrl: false`), Apple nonce hashing, native callback allowlist, MCP body/rate-limit/OAuth origin checks, Apple token revoke on delete, board alerts loaded from the database, and FORCE RLS on user tables were already in tree. This pass did not reopen those PRs or touch `hillclimb/ui`, #212, or #213.
