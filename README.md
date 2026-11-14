# Notepad

Notepad is a small reminder board for iPhone, the web, and the Lock Screen. It uses Supabase for accounts and shared data, with a React/Vite web app, an iOS 17+ app and WidgetKit extension, and an MCP server for agents. The app is free, with no in-app purchases or subscriptions.

The product name and iOS app display name are **Notepad**. The repository, Xcode project, and bundle identifiers still use `lazy-mans-reminders` / `LazyMansReminders`. App Store app id: [`6799138197`](https://apps.apple.com/app/id6799138197). Support: [edmund@sillyapps.co](mailto:edmund@sillyapps.co).

## Addresses

| Service | Canonical address | Project |
| --- | --- | --- |
| Landing page | <https://notepads.dev> | Cloudflare Pages `notepads-landing` |
| Web board | <https://app.notepads.dev> | Cloudflare Pages `lazy-mans-reminders` |
| Agent MCP | <https://np-mcp.sillyapps.co/mcp> | Cloudflare Worker `lazy-mans-reminders-mcp` |
| Supabase | `https://biwmsxbqrevtjwgsvsmu.supabase.co` | `lazy-mans-reminders`, Singapore |

The legacy web hosts <https://np.sillyapps.co> and <https://lmr.sillyapps.co> stay live alongside the canonical host (dual-serve, no 301). <https://lazy-mans-reminders.pages.dev> is the Pages fallback. The older <https://lmr.edmundlim.systems> stays attached and 302s to `lmr.sillyapps.co`, preserving path and query for old builds and links. The legacy MCP endpoint <https://lmr-mcp.edmundlim.systems/mcp> also stays live without a 301.

[Privacy](https://app.notepads.dev/privacy), [terms](https://app.notepads.dev/terms), and [support](https://app.notepads.dev/support) use the canonical web host; the same paths exist on the legacy web hosts. These addresses describe the setup, not a fresh production or App Store status check.

## Repository

| Path | Contents |
| --- | --- |
| `ios/` | iOS app, widgets, shared code, tests, and XcodeGen `project.yml` |
| `web/` | Vite/React web app and legal pages |
| `mcp/` | Cloudflare Worker MCP server and OAuth |
| `landing/` | Static notepads.dev site |
| `supabase/` | Database migrations, Edge Functions, and SQL tests |
| `plugins/lazy-mans-reminders/` | Agent and Cursor plugin manifests and instructions |
| `docs/` | Product, data handling, and native/release reference docs |
| `scripts/` | Validation, build, and operator utilities |
| `.github/workflows/` | CI and TestFlight workflows |

## Current behavior

`ios/project.yml` sets marketing version **1.0.1** and `CURRENT_PROJECT_VERSION` **11**. Those are source values, not a claim about the latest uploaded build.

- One shared board supports reminders, completion, reordering, iPhone push, widgets, and a Lock Screen Live Activity. Live Activity visibility and updates depend on iOS settings, connectivity, and system limits.
- Account offers **Default**, **Minimal**, and **Bold** app icons.
- iPhone accessibility work includes VoiceOver and Voice Control labels, **Move up / Move down** reorder actions, Reduce Motion, stronger Increase Contrast / Reduce Transparency treatment, and primary-color error text. Publish accessibility support claims only after device QA.
- Done reminders older than **3 days**, measured from `completed_at`, are removed by `delete_old_completed_reminders()`. Web and iOS request this cleanup on board load. It is best effort: inactivity, locks, and write budgets can delay removal. A daily cron call is optional. Push-job logs have a separate **7-day** retention policy. See [retention and data copy](docs/copy/retention-and-data-copy.md).
- In-house daily usage counters are implemented; there is no PostHog integration. Collection defaults off through `usage_analytics_config.enabled=false`. Worker tool/OAuth counters additionally require `USAGE_ANALYTICS_ENABLED=true`, so those events require both flags. See [the analytics design and enablement prerequisites](docs/analytics/plan.md).

### Routine reminders

Create and edit routines under **Routine reminders** on the [web board](https://app.notepads.dev). Choose one weekday for a weekly reminder, or a start date and an interval of **1–365 days**, plus a time and IANA timezone. The timezone stays fixed when you travel; scheduling follows local time across daylight-saving changes.

The database stores `routine_reminders`; its scheduler checks every minute, creates or reactivates a board row, and sends an iPhone push through the existing APNs path. Due routines move to the top, including when the board is full. Completing or deleting the generated reminder keeps the routine running; pause or delete the routine to stop future occurrences. Deleting a routine preserves its current board row. After an outage, one overdue occurrence fires and missed intervals are skipped.

Routine data is included in web exports and account deletion. iOS receives and completes generated reminders; routine editing is on the web. Push delivery depends on network and notification settings. There are no web push notifications.

## Local setup

Use Node.js **22** (as in web/MCP CI) and npm. Database development needs the Supabase CLI and Docker; Edge Function checks use Deno 2. Native development needs macOS, Xcode, and XcodeGen. The native workflows and `ios/project.yml` currently select **Xcode 27.1**, with an iOS 17 deployment target.

Copy the example configuration files and fill in local values:

```sh
cp web/.env.example web/.env.local
cp ios/Config.example.xcconfig ios/Config.xcconfig
```

Client configuration:

- Web: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`.
- iOS: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `DEVELOPMENT_TEAM`, `PRODUCT_BUNDLE_IDENTIFIER`, `WIDGET_BUNDLE_IDENTIFIER`, `APP_GROUP_ID`.

The URL and publishable/anon key are client values; access control depends on Supabase RLS. Never put a service-role key or other server secret in Vite or the iOS config. Keep local config and credentials out of source control.

Run the web app:

```sh
cd web
npm ci
npm run dev
```

For a disposable local database, `supabase start` starts the stack and `supabase db reset` recreates it from migrations. Reset discards local data. Point client configuration at that local instance when testing it. Live database migrations belong to the separately authorized operator workflow below.

### Authentication configuration

[`supabase/config.toml`](supabase/config.toml) still sets `site_url = "https://np.sillyapps.co"`. Current clients and legal links use `https://app.notepads.dev`. Repository config does not establish the live dashboard Site URL.

The repository redirect allowlist is:

| Origin | Allowed entries |
| --- | --- |
| `https://app.notepads.dev` | Bare origin, `/**`, `/auth/callback`, `/auth/ios` |
| `https://np.sillyapps.co` | Bare origin, `/auth/callback`, `/auth/ios` |
| `https://lmr.sillyapps.co` | Bare origin, `/auth/callback`, `/auth/ios` |
| `https://lmr.edmundlim.systems` | Bare origin, `/auth/callback`, `/auth/ios` |
| `https://lazy-mans-reminders.pages.dev` | Bare origin, `/auth/callback`, `/auth/ios` |
| `http://localhost:5173` | Bare origin, `/auth/callback` |
| iOS custom scheme | `lazymansreminders://auth/callback` |

The HTTPS `/auth/ios` path hands magic links to iOS; the custom scheme remains unchanged. Keep legacy entries for old builds. Email signup/confirmation is enabled in the repo config; Apple and Google are disabled local stubs, with hosted provider settings managed separately. Do not treat these stubs as production provider configuration or push them over hosted settings.

### iOS build

```sh
brew install xcodegen
xcodegen generate --spec ios/project.yml
open ios/LazyMansReminders.xcodeproj
```

Make lasting project-setting changes in `ios/project.yml`. The signing identifiers are:

- App: `systems.edmundlim.LazyMansReminders`
- Widget: `systems.edmundlim.LazyMansReminders.Widget`
- App Group: `group.systems.edmundlim.LazyMansReminders`

For device builds, configure the Apple Developer team, matching app/extension identifiers and profiles, the shared App Group, Sign in with Apple, and Push Notifications. Confirm Background Modes for remote notifications and fetch. `APNS_TOPIC` must match the app bundle identifier. Debug uses sandbox APNs tokens; Release/TestFlight uses production tokens.

After a signed-in launch, Siri/Shortcuts can list reminders, add a reminder, or mark one done. Phrases use `\(.applicationName)`, so examples are **“List reminders in Notepad”**, **“Add a reminder in Notepad”**, and **“Mark this as done in Notepad”**. Signed-out requests say to sign in to Notepad on this iPhone first. SDK-gated reminders-domain schemas are not proof of Siri behavior; test the selected artifact. See [the native handoff](MAC_HANDOFF.md) for build and device QA.

## Agent MCP

Use `https://np-mcp.sillyapps.co/mcp`; `https://lmr-mcp.edmundlim.systems/mcp` remains available. OAuth is the usual path: add the endpoint to the host, sign in on the [board](https://app.notepads.dev), then select **Allow**. For Grok Bot, use **Settings → Plugins → custom connector**.

Cursor, Claude Code, and Codex can load `plugins/lazy-mans-reminders/`; see its [README](plugins/lazy-mans-reminders/README.md) for the two manifest formats. Clients supporting remote MCP can also use:

```json
{
  "mcpServers": {
    "lazy-mans-reminders": {
      "url": "https://np-mcp.sillyapps.co/mcp"
    }
  }
}
```

For hosts that cannot use OAuth, personal agent keys remain under **Agent access → Advanced**. Configure `LMR_AGENT_TOKEN` through the host's private settings. Never commit a token or paste it into chat. The Worker accepts OAuth sessions or personal keys; its Supabase service-role key stays server-side.

`mcp/wrangler.jsonc` lists `https://app.notepads.dev` first in `WEB_ORIGINS`, which determines the board origin used by `/authorize` for `/connect`.

## Checks

From the repository root, run the checks relevant to your change:

```sh
(cd web && npm ci && npm test && npm run lint && npm run build)
(cd mcp && npm ci && npm test && npm run typecheck)
deno test supabase/functions/_shared supabase/functions/delete-account
deno check supabase/functions/send-reminder-push/index.ts supabase/functions/delete-account/index.ts
python3 -B -m unittest discover -s scripts/tests -v
python3 scripts/check_migration_versions.py
```

The script tests include PostgreSQL cases; see CI for their disposable database setup. Routine SQL tests live in `supabase/tests/routine_reminders.sql`; the web/MCP workflow records the migration/test sequence and rollback fixtures. Use a disposable database, not production.

On a Mac, after generating the Xcode project:

```sh
./scripts/check-ios-toolchain.sh
./scripts/ios-release-build.sh
./scripts/ios-simulator-unit-tests.sh
```

### CI triggers

All four workflows support `workflow_dispatch`.

| Workflow | Pull requests | Pushes | Checks |
| --- | --- | --- | --- |
| [`ios-tests.yml`](.github/workflows/ios-tests.yml) | All paths | `main`, `dev`: `ios/**`, `scripts/**`, or its workflow file | Third-party sign-in flags off; Release app/widget build and simulator unit tests |
| [`web-mcp-checks.yml`](.github/workflows/web-mcp-checks.yml) | All paths | `main`, `dev`: `web/**`, `landing/**`, `mcp/**`, `supabase/**`, `scripts/**`, or its workflow file | Web tests/lint/build, MCP tests/typecheck, release-script tests, routine database/push tests |
| [`ios-persistence-checks.yml`](.github/workflows/ios-persistence-checks.yml) | `ios/**`, `supabase/**`, `scripts/**`, or its workflow file | None | Reorder/reopen database tests, simulator tests, server lifecycle tests |
| [`ios-testflight.yml`](.github/workflows/ios-testflight.yml) | None | `main` only: `ios/**`, `scripts/**`, or its workflow file | Signed TestFlight build/upload |

## Branching and releases

`dev` is the default working branch. Feature and fix PRs target `dev`; a release is a PR from `dev` into `main`. See [AGENTS.md](AGENTS.md). Merging into `dev` does not upload a TestFlight build or authorize a deployment/submission.

TestFlight uses the `xcode-27` runner and Xcode 27.1. Its workflow can run on the filtered `main` pushes above or manual dispatch. `CURRENT_PROJECT_VERSION` is the source build-number floor; export enables automatic build-number management, so confirm the actual uploaded artifact rather than inferring it from the source pin.

Native verification is covered in [MAC_HANDOFF.md](MAC_HANDOFF.md). [App Store notes](docs/app-store.md) hold metadata guidance; [HUMANS.md](HUMANS.md) and dated release audits preserve historical evidence. Linux cannot run Xcode, and hosted CI does not establish physical-device behavior. App Store submission requires Edmund's authorization and verified release evidence.

## Operator reference

Production web, landing, MCP Worker, Edge Function deploys and live database migrations are performed by **jeremy after Edmund explicitly OKs them**. The commands below are references for that authorized work, not contributor setup steps. No production state is verified by this README.

### Server secrets

Keep server-only values in private operator storage or ignored files such as `supabase/.env.functions`, never client bundles, source, screenshots, or command history.

| Component | Configuration |
| --- | --- |
| Push function | `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC`, `WEBHOOK_SECRET` |
| Apple revocation in `delete-account` | `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_ID` |
| Supabase Edge Functions | Supabase provides `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` |
| MCP Worker | Server-side `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`; bindings/routes in `mcp/wrangler.jsonc` |
| TestFlight workflow | `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY_B64`, `APPSTORE_CERTIFICATES_FILE_BASE64`, `APPSTORE_CERTIFICATES_PASSWORD` |

The APNs and Sign in with Apple keys serve different purposes. Private-key values accept escaped `\n` newlines. Native Apple revocation uses `APPLE_CLIENT_ID=systems.edmundlim.LazyMansReminders`, not the web Services ID. Deletion success alone does not prove Apple token revocation; verify cancellation, error, and manual-fallback paths on the release artifact.

### Backend reference

The existing project's ref is `biwmsxbqrevtjwgsvsmu`. For an approved migration/function rollout, the CLI commands are:

```sh
supabase login
supabase link --project-ref biwmsxbqrevtjwgsvsmu
supabase db push
supabase secrets set --env-file supabase/.env.functions
supabase functions deploy send-reminder-push --no-verify-jwt
supabase functions deploy delete-account
```

`send-reminder-push` authenticates webhook requests using `x-webhook-secret`; `delete-account` retains JWT verification. The webhook targets `https://biwmsxbqrevtjwgsvsmu.supabase.co/functions/v1/send-reminder-push` for INSERT, UPDATE, and DELETE on `public.reminders`. Its header must match `WEBHOOK_SECRET`. Check deployed trigger/secrets configuration separately; do not infer it from old deployment notes.

Push delivery uses retries and replay jobs; permanent invalid-device failures remove tokens. A production push check needs a registered physical iPhone with the appropriate APNs environment. Simulator success or an accepted APNs request alone is not device-delivery evidence.

### Cloudflare reference

Web Pages settings are root `web`, build command `npm run build`, output `dist`, and client variables `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`. The project name remains `lazy-mans-reminders` despite the canonical domain change. Never put the service-role key on Pages.

Existing web deployment command, for the approved operator:

```sh
cd web
npm ci
npm run build
npx wrangler pages deploy dist --project-name lazy-mans-reminders --branch main
```

The MCP package's `npm run deploy` runs `wrangler deploy` using `mcp/wrangler.jsonc`. Keep both MCP custom domains and legacy web aliases. The static site's separate command and project are documented in [landing/README.md](landing/README.md).

## License

Licensed under [CC BY-NC-4.0](https://creativecommons.org/licenses/by-nc/4.0/). See [LICENSE](LICENSE).
