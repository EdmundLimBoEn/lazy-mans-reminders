# Lazy Man's Reminders

A Supabase-backed reminder board with a React/Vite web app and an iOS 17 app plus WidgetKit extension. The iOS app receives APNs notifications and refreshes the shared widget data.

## Current deployment status

As of 6 August 2026:

- Web app: **live** at <https://lmr.edmundlim.systems> (alias) and <https://lazy-mans-reminders.pages.dev>
- Cloudflare Pages project: `lazy-mans-reminders`
- Supabase project: `lazy-mans-reminders` (`biwmsxbqrevtjwgsvsmu`, Singapore)
- Database migrations: **deployed**
- Supabase Auth production URL and redirects: **deployed** (site URL `https://lmr.edmundlim.systems`)
- `send-reminder-push` Edge Function: **deployed, but inactive until APNs secrets and its database webhook are configured**
- iOS app and widget: **implemented; XcodeGen project generated locally, not yet signed or uploaded to TestFlight**

### Deferred launch checklist

Complete these items from a Mac with the Apple Developer account:

- [ ] Confirm DNS: proxied CNAME `lmr` → `lazy-mans-reminders.pages.dev` on the `edmundlim.systems` zone (Pages domain already registered).
- [ ] Create App IDs `systems.edmundlim.LazyMansReminders` + `.Widget`, and App Group `group.systems.edmundlim.LazyMansReminders`; enable Push Notifications and the App Group capability.
- [ ] Create an APNs `.p8` key and put `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC`, and a generated `WEBHOOK_SECRET` in `supabase/.env.functions`.
- [ ] Run `supabase secrets set --env-file supabase/.env.functions`.
- [ ] Create the `public.reminders` `INSERT` database webhook described below, using the same `WEBHOOK_SECRET`.
- [ ] Open `ios/LazyMansReminders.xcodeproj`, sign both targets, then test magic-link login, push delivery, and both lock-screen widget sizes on a physical iPhone.
- [ ] Upload to TestFlight and complete the paid-app release at US $2.99.
- [ ] Enroll in Apple's App Store Small Business Program before release.

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
2. Authenticate the CLI, link this checkout, and apply both migrations:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

The migrations create `reminders` and `device_tokens`, enable RLS, add per-user policies, and enable Realtime for reminders.

For a fully local stack:

```sh
supabase start
supabase db reset
```

### Configure passwordless authentication

In Supabase **Authentication → URL Configuration**:

- Set the Site URL to `https://lmr.edmundlim.systems`.
- Add `http://localhost:5173/auth/callback`.
- Add `https://lmr.edmundlim.systems/auth/callback`.
- Add `https://lazy-mans-reminders.pages.dev/auth/callback` as a fallback.
- Add `lazymansreminders://auth/callback` for iOS.

Keep `supabase/config.toml` aligned for local development. In **Authentication → Providers → Email**, enable email sign-in and confirmations. Test a magic link from both the web app and a physical iPhone; the production hostname must exactly match an allowed redirect.

### Deploy push delivery

Upload the server-only secrets first, then deploy the Edge Function:

```sh
supabase functions deploy send-reminder-push --no-verify-jwt
```

JWT verification is intentionally disabled because the database webhook authenticates with `x-webhook-secret`. The function checks that shared secret before using the service-role client.

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

The generated project can be recreated; make lasting project-setting changes in `ios/project.yml`.

## TestFlight

1. Create the app record in App Store Connect using the exact app bundle ID.
2. In Xcode, select **Any iOS Device (arm64)**, then **Product → Archive**.
3. In Organizer, choose **Distribute App → App Store Connect → Upload**.
4. Wait for processing, answer export-compliance questions, add internal testers, and verify sign-in, sync, widget refresh, and production push delivery.
5. For external testing, create a group, add testing notes, and submit the build for Beta App Review.

Increment the marketing version/build number before each upload.

## Paid App Store release ($2.99)

This is a paid download, not an in-app purchase:

1. Accept the latest **Paid Apps Agreement** and complete tax and banking details in App Store Connect.
2. Under the app's **Pricing and Availability**, choose the price point whose US storefront price is **$2.99**. Apple calculates local storefront prices and taxes.
3. Complete app metadata, privacy details, age rating, screenshots, support/privacy URLs, and App Review notes.
4. Attach the tested build, choose manual or automatic release, and submit for review.

Before submission, verify that account deletion requirements, privacy disclosures, support contact, and reviewer access/instructions match the shipped app.

## App Store Small Business Program

Eligible developers can apply for Apple's App Store Small Business Program for a reduced commission (generally 15%). Enrollment is not automatic:

1. Review Apple's current eligibility rules, including the prior-calendar-year proceeds threshold and associated developer accounts.
2. Ensure all agreements, tax, banking, and membership details are current.
3. Apply from the Apple Developer/App Store Connect enrollment page and disclose associated accounts.
4. Wait for approval before assuming the reduced rate in financial forecasts; Apple applies the current program terms and eligibility rules.

Re-check Apple's official terms before launch because thresholds, definitions, and commissions can change.
