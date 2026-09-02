# Lazy Man's Reminders

A Supabase-backed reminder board with a React/Vite web app and an iOS 17 app plus WidgetKit extension. The iOS app receives APNs notifications and refreshes the shared widget data. The App Store release is **free** (no in-app purchases).

## Current deployment status

As of 26 August 2026. The iOS app ships as a **free** App Store download (no in-app purchases).

- Web app: **live** at <https://lmr.edmundlim.systems> and <https://lazy-mans-reminders.pages.dev>
- Cloudflare Pages project: `lazy-mans-reminders`
- Supabase project: `lazy-mans-reminders` (`biwmsxbqrevtjwgsvsmu`, Singapore)
- Database migrations: **deployed** (including agent tokens)
- Supabase Auth: site URL and redirects **deployed**; Apple web + native configured; Google provider enabled; Resend SMTP for magic-link email
- `send-reminder-push` and `delete-account` Edge Functions: **deployed**
- Agent MCP Worker: **live** at <https://lmr-mcp.edmundlim.systems/mcp> (OAuth plugin path)
- iOS app and widget: **implemented**; TestFlight build uploaded; physical-device smoke and App Store submission still open. Submission fields live in [docs/app-store.md](docs/app-store.md).
- Lock Screen: Live Activity plus accessory widgets; push alerts are body-only (no title)
- Custom domain DNS: **active** for web and MCP

### Deferred launch checklist

See [HUMANS.md](HUMANS.md) for the live checklist. Remaining human work:

- [ ] Open `ios/LazyMansReminders.xcodeproj`, sign both targets, then test Apple / Google / magic-link login, push, widgets, and account deletion on a physical iPhone.
- [ ] Finish TestFlight external testing as needed, then submit the **free** App Store release (Pricing and Availability: Free).

## Prerequisites

- Node.js 20+ and npm
- A Supabase account and Supabase CLI
- A Cloudflare account and Wrangler CLI (included in `web`)
- macOS with Xcode 16+, XcodeGen, and an Apple Developer Program membership

## Configuration and secrets

Do not commit real credentials. Copy the example files locally:

```sh
cp web/.env.example web/.env.local
cp ios/Config.example.xcconfig ios/Config.xcconfig
```

Client configuration (safe to ship, but keep environment-specific values out of source):

- `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in `web/.env.local`
- `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `ios/Config.xcconfig`
- `DEVELOPMENT_TEAM`, `PRODUCT_BUNDLE_IDENTIFIER`, `WIDGET_BUNDLE_IDENTIFIER`, and `APP_GROUP_ID` in `ios/Config.xcconfig`

Server-only secrets (never put these in Vite, the iOS config, source control, screenshots, or command history):

- `APNS_KEY_ID`: Apple APNs key ID
- `APNS_TEAM_ID`: Apple Developer Team ID
- `APNS_PRIVATE_KEY`: contents of the downloaded `.p8` key, with newlines represented as `\n`
- `APNS_TOPIC`: the iOS app bundle identifier
- `WEBHOOK_SECRET`: a long random value shared only by the database webhook and Edge Function
- `SUPABASE_SERVICE_ROLE_KEY`: provided automatically to the deployed Supabase Edge Function; never expose it to clients

Store the five custom function values in an ignored file such as `supabase/.env.functions`, then upload that file:

```sh
supabase secrets set --env-file supabase/.env.functions
```

## Supabase

### Create and migrate the project

1. Create a project in the Supabase dashboard and record its project ref, URL, and publishable/anon key.
2. Authenticate the CLI, link this checkout, and apply migrations:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

The migrations create `reminders`, `device_tokens`, `lock_screen_prefs`, and `agent_tokens`, enable RLS, add per-user policies, and enable Realtime for reminders. Agent keys are minted with `mint_agent_token` and listed through the `agent_token_clients` view (no hash). Concurrent agent adds go through `add_agent_reminder`, which locks per user and clamps capacity at 16. The iPhone measures how many lines fit in the Lock Screen Live Activity and upserts `lock_screen_prefs.max_lines` so the web board uses the same capacity. Completed reminders get a `completed_at` timestamp (maintained by a trigger); web and iOS call `delete_old_completed_reminders()` on board load so done rows older than 7 days are removed without requiring dashboard cron.

Optional: if you enable the `pg_cron` extension in the Supabase dashboard, you can also schedule `select public.delete_old_completed_reminders();` daily so cleanup runs even when no client opens the board.

For a fully local stack:

```sh
supabase start
supabase db reset
```

### Configure authentication

In Supabase **Authentication → URL Configuration**:

- Set the Site URL to `https://lmr.edmundlim.systems`.
- Add `http://localhost:5173/auth/callback`.
- Add `https://lmr.edmundlim.systems/auth/callback`.
- Add `https://lazy-mans-reminders.pages.dev/auth/callback` as a fallback.
- Add `lazymansreminders://auth/callback` for iOS Google OAuth.
- Add `https://lmr.edmundlim.systems/auth/ios` and `https://lazy-mans-reminders.pages.dev/auth/ios` for iOS magic-link handoff.
- Also allow the bare origins used by OAuth returns: `http://localhost:5173`, `https://lmr.edmundlim.systems`, and `https://lazy-mans-reminders.pages.dev`.

Keep `supabase/config.toml` aligned for local development. In **Authentication → Providers**:

- Enable **Email** (magic link) with confirmations.
- Enable **Apple** and **Google** using the steps in `HUMANS.md` (Services ID + secret for web Apple; Web OAuth client for Google; iOS App ID in Apple Client IDs).

Test Apple, Google, and a magic link from both the web app and a physical iPhone; the production hostname must exactly match an allowed redirect.

### Deploy push delivery

Upload the server-only secrets first, then deploy the Edge Functions:

```sh
supabase functions deploy send-reminder-push --no-verify-jwt
supabase functions deploy delete-account
```

`send-reminder-push` disables JWT verification because the database webhook authenticates with `x-webhook-secret`. The function checks that shared secret before using the service-role client.

Delivery behaviour:

- Each APNs request sets `apns-expiration` 24 hours out so alerts are stored if the phone is offline, and `apns-collapse-id` equal to the reminder id so webhook retries replace the same banner instead of stacking duplicates.
- Transient APNs failures (network, 429, 5xx, expired provider JWT) are retried inside the function. If any device is still retryable afterwards the function returns **503** so the webhook / `pg_net` trigger can try the whole job again. Permanent failures (including `410 Unregistered` and `400 BadDeviceToken`) prune that token and still return 200.
- After changing this function, redeploy with `supabase functions deploy send-reminder-push --no-verify-jwt`. The INSERT trigger itself (`notify_reminder_push` / dashboard webhook) is configured in the project, not this repo.

`delete-account` keeps JWT verification on. Signed-in clients call it to delete the caller's reminders, device tokens, agent tokens, and auth user (service role).

## Agent MCP

Remote agents talk to the board at `https://lmr-mcp.edmundlim.systems/mcp`. The usual path is OAuth: the client opens a browser, you sign in on the familiar board, tap Allow. No bearer tokens to paste. Personal keys remain under **Advanced** on the signed-in board for clients that cannot do OAuth.

Grok: Settings → Plugins → custom connector → URL `https://lmr-mcp.edmundlim.systems/mcp` (no headers). Cursor / Claude Code / Codex can load `plugins/lazy-mans-reminders/` or the same URL in `mcp.json`:

```json
{
  "mcpServers": {
    "lazy-mans-reminders": {
      "url": "https://lmr-mcp.edmundlim.systems/mcp"
    }
  }
}
```

The Worker uses the service-role key as a Wrangler secret; never put that key on Pages. The web app only calls `/bind` with the user's Supabase session.

In Supabase **Database → Webhooks**, create a webhook with:

- Name: `send-reminder-push`
- Table: `public.reminders`
- Event: `INSERT`
- Method: `POST`
- URL: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-reminder-push`
- Header: `x-webhook-secret: <the exact WEBHOOK_SECRET value>`

Insert a reminder after registering a physical device and inspect **Edge Functions → Logs**. Simulator push tokens and sandbox tokens do not validate production APNs delivery.

## Web app and Cloudflare Pages

Run locally:

```sh
cd web
npm ci
npm run dev
```

Validate a production build:

```sh
cd web
npm ci
npm run lint
npm run build
```

### Tests

```sh
# Web (Vitest — routing + reminder sort/reorder helpers)
cd web && npm test

# MCP Worker (Vitest — token parse/hash + add prefix/capacity mapping)
cd mcp && npm test

# Edge Function helpers (Deno — webhook payload classification / APNs host)
deno test supabase/functions/_shared/push_helpers_test.ts

# iOS (XCTest — Reminder JSON coding; regenerate project first if needed)
cd ios && xcodegen generate --spec project.yml
xcodebuild -project LazyMansReminders.xcodeproj -scheme LazyMansReminders \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:LazyMansRemindersTests test
```

For a Git-connected Cloudflare Pages project, configure:

- Root directory: `web`
- Build command: `npm run build`
- Build output directory: `dist`
- Production and Preview variables: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`

These two `VITE_` values are embedded in the browser bundle and are not server secrets; security depends on Supabase RLS. Never add the service-role key to Cloudflare Pages.

Deploy manually after `wrangler login`:

```sh
cd web
npm ci
npm run build
npx wrangler pages deploy dist --project-name lazy-mans-reminders
```

Custom domain: `lmr.edmundlim.systems` is registered on the Pages project. Ensure a proxied CNAME `lmr` → `lazy-mans-reminders.pages.dev` exists on the `edmundlim.systems` zone, then keep Supabase Auth redirects in sync (see above).

## iOS

### Apple identifiers, App Group, and APNs

In Apple Developer **Certificates, Identifiers & Profiles**:

1. Register an explicit App ID for the app and another for the widget extension.
2. Create an App Group and enable it for both identifiers.
3. Enable **Push Notifications** for the app identifier.
4. Create an APNs authentication key, download its `.p8` file once, and record its Key ID and Team ID.
5. Create or refresh development and App Store provisioning profiles after enabling capabilities.

The `PRODUCT_BUNDLE_IDENTIFIER`, widget identifier, and `APP_GROUP_ID` in `ios/Config.xcconfig` must exactly match the portal. `APNS_TOPIC` must equal `PRODUCT_BUNDLE_IDENTIFIER`. Debug builds register sandbox tokens; Release/TestFlight builds register production tokens.

### Generate and run the Xcode project

Copy config, install XcodeGen if needed, and generate the project:

```sh
cp ios/Config.example.xcconfig ios/Config.xcconfig
# set DEVELOPMENT_TEAM (DUU8J39BA7 for Edmund Lim) if needed
brew install xcodegen
xcodegen generate --spec ios/project.yml
open ios/LazyMansReminders.xcodeproj
```

Bundle IDs (must match Apple Developer portal):

- App: `systems.edmundlim.LazyMansReminders`
- Widget: `systems.edmundlim.LazyMansReminders.Widget`
- App Group: `group.systems.edmundlim.LazyMansReminders`

In Xcode:

1. Select the development team for both targets and confirm automatic signing resolves profiles.
2. Confirm the app has **Push Notifications** and **Background Modes → Remote notifications**.
3. Confirm both targets show the same App Group.
4. Run on a physical iPhone, sign in through the `lazymansreminders://auth/callback` link, allow notifications, and add the widget.

Siri (iOS 26+, Apple Intelligence on iOS 27): after a signed-in launch, the app donates the board to Spotlight and exposes App Intents in the reminders domain. From Siri you can list the board, add a line, or mark one done (“complete milk”, “mark this as done”). The phone must be signed in; unsigned-in requests tell you to open the app first. Shortcuts phrases use the app name **Lazy Man's Reminders**.

The generated project can be recreated; make lasting project-setting changes in `ios/project.yml`.

## TestFlight

1. Create the app record in App Store Connect using the exact app bundle ID.
2. In Xcode, select **Any iOS Device (arm64)**, then **Product → Archive**.
3. In Organizer, choose **Distribute App → App Store Connect → Upload**.
4. Wait for processing, answer export-compliance questions, add internal testers, and verify sign-in, sync, widget refresh, and production push delivery.
5. For external testing, create a group, add testing notes, and submit the build for Beta App Review.

Increment the marketing version/build number before each upload.

## Free App Store release

The iOS app is a free download with no in-app purchases or subscriptions.

1. In App Store Connect, under **Pricing and Availability**, set the price to **Free** for the storefronts you ship.
2. Complete app metadata, privacy details, age rating, screenshots, support URL (`https://lmr.edmundlim.systems/support`), and privacy URL (`https://lmr.edmundlim.systems/privacy`). Use [docs/app-store.md](docs/app-store.md) for nutrition labels and review notes.
3. Attach a tested build, choose manual or automatic release, and submit for review.

Before submission, confirm account deletion, privacy disclosures, support contact, and reviewer notes match the shipped app.
