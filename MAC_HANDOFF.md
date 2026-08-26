# Mac handoff — Lazy Man's Reminders

**Date:** 7 August 2026  
**From:** Linux agent session (launch-ready / monetization prep)  
**Repo:** `git@github.com:EdmundLimBoEn/lazy-mans-reminders.git`  
**Branch:** `main` @ `89c0abb` (pulled/pushed; includes launch work + prior lock-screen widget fix)  
**Operator:** Edmund Lim · team `DUU8J39BA7` · contact `hello@edmundlim.systems`

Use this on your **Mac + Zen browser** (authed sessions). Paste the “Agent prompt” section into a Mac Cursor agent if you want it to drive the remaining dashboard/Xcode work.

---

## 1. What this product is

Passwordless reminder board:

- **Web** (React/Vite) — create/edit/reorder/complete reminders  
- **iOS 17 app** — magic link / Apple / Google sign-in, complete reminders, register for push  
- **Lock Screen widget** — shows active reminders (marquee scroll for long lines; clear Liquid Glass layout from commit `13c6df5`)  
- **Backend** — Supabase Auth + Postgres RLS + Realtime + Edge Functions (push + account delete)

**Live URLs**

| What | URL |
|------|-----|
| Web (alias) | https://lmr.edmundlim.systems |
| Web (Pages) | https://lazy-mans-reminders.pages.dev |
| Privacy | https://lmr.edmundlim.systems/privacy |
| Terms | https://lmr.edmundlim.systems/terms |
| Support | https://lmr.edmundlim.systems/support |
| Supabase project | `biwmsxbqrevtjwgsvsmu` (Singapore / `ap-southeast-1`) |
| Dashboard | https://supabase.com/dashboard/project/biwmsxbqrevtjwgsvsmu |
| Auth providers | https://supabase.com/dashboard/project/biwmsxbqrevtjwgsvsmu/auth/providers |
| Functions | https://supabase.com/dashboard/project/biwmsxbqrevtjwgsvsmu/functions |

**Planned monetization:** paid App Store app ~US $1.50 / S$2.00 (one-time). Email magic link alone does **not** require Sign in with Apple; offering Google **does** (Guideline 4.8). Code already includes Apple + Google.

---

## 2. Sync the Mac first

```sh
cd /path/to/lazy-mans-reminders   # or clone fresh
git fetch origin
git checkout main
git pull --ff-only origin main
git log -3 --oneline
# expect tip: 89c0abb Mark delete-account Edge Function as deployed.
```

Local config (do not commit):

```sh
cp web/.env.example web/.env.local
# set VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY (same as production publishable key)

cp ios/Config.example.xcconfig ios/Config.xcconfig
# DEVELOPMENT_TEAM = DUU8J39BA7
# PRODUCT_BUNDLE_IDENTIFIER = systems.edmundlim.LazyMansReminders
# WIDGET_BUNDLE_IDENTIFIER = systems.edmundlim.LazyMansReminders.Widget
# APP_GROUP_ID = group.systems.edmundlim.LazyMansReminders
# SUPABASE_URL / SUPABASE_ANON_KEY from example / dashboard

cd ios && xcodegen generate   # if needed
open LazyMansReminders.xcodeproj
```

---

## 3. Already done (do not redo)

### Product / code (on `main`)

- Privacy, Terms, Support SPA routes + footer links (`web/src/LegalPages.tsx`, routed in `App.tsx`)
- Web UI polish: tighter mobile spacing, smaller headlines, reliable complete tap targets
- Web + iOS **account deletion** → `delete-account` Edge Function
- iOS **complete reminder** (was broken: list had no PATCH) via `ReminderStore.markDone`
- iOS Sign in with Apple (native `SignInWithAppleButton` + nonce + `signInWithIdToken`)
- iOS Google via `signInWithOAuth` / ASWebAuthenticationSession (no GoogleSignIn SDK)
- Web Continue with Apple / Google OAuth buttons + email magic link
- Sign in with Apple entitlement in `LazyMansReminders.entitlements` + XcodeGen capability
- Lock Screen widget rewrite kept from remote (`13c6df5`) — full-width clear glass + marquee; **do not** revert to the old “REMINDERS” header layout

### Infra (mostly done on Linux / earlier Mac work)

| Item | Status |
|------|--------|
| DNS `lmr` → Pages | Done (active) |
| App / Widget IDs + App Groups + Push | Done (`9H8ZY6WGY6` / `PBM95Q8YTQ`) |
| APNs secrets + reminder INSERT → push path | Done (verify on device) |
| Email auth | Enabled |
| **Apple provider in Supabase** | **Enabled** via API — Client ID = `systems.edmundlim.LazyMansReminders`, **no web secret yet** |
| Google provider | **Not enabled** (needs OAuth client from Zen/Google Cloud) |
| `delete-account` function | **Deployed** |
| Web app | **Deployed** to Pages (200 on `/`, `/privacy`) |

### Auth config snapshot (as of deploy)

- `site_url` = `https://lmr.edmundlim.systems`
- Redirect allow list includes localhost, Pages, `lmr`, and `lazymansreminders://auth/callback`
- `external_apple_enabled` = true  
- `external_apple_client_id` = `systems.edmundlim.LazyMansReminders`  
- `external_apple_secret` = none (web Apple OAuth will fail until Services ID + secret)  
- `external_google_enabled` = false  

---

## 4. What YOU must finish on Mac (Zen)

Checklist also lives in `HUMANS.md`. Priority order for “friends want to try it”:

### A. Google SSO (highest leverage for web testers)

1. Zen → [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. Create **OAuth client ID** → application type **Web application**
3. Authorized JavaScript origins:
   - `https://lmr.edmundlim.systems`
   - `https://lazy-mans-reminders.pages.dev`
   - `http://localhost:5173`
4. Authorized redirect URI:
   - `https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback`
5. Optional: separate **iOS** OAuth client with bundle ID `systems.edmundlim.LazyMansReminders` (Supabase still uses the **Web** client ID/secret as the provider credentials)
6. Zen → Supabase → Authentication → Providers → **Google** → enable → paste Web client ID + secret → Save
7. Smoke test: https://lmr.edmundlim.systems → Continue with Google

### B. Sign in with Apple capability (required for native + for Guideline 4.8 once Google is on)

1. [Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list) → App ID `systems.edmundlim.LazyMansReminders`
2. Enable **Sign in with Apple** → Save
3. Xcode: regenerate/signing profiles if needed; confirm entitlement `com.apple.developer.applesignin` is present
4. Device test: native Apple button on sign-in screen

### C. Web Apple (optional but buttons exist)

Native Apple can work with App ID alone. **Web** Continue with Apple needs:

1. Apple **Services ID** (e.g. `systems.edmundlim.LazyMansReminders.web`)
2. Domains/return URL for Supabase callback:  
   `https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback`
3. Sign in with Apple **key** (`.p8`) → generate client secret (Supabase docs have a generator)
4. Supabase Apple provider **Client IDs** order matters:
   - **First:** Services ID (web OAuth)
   - **Also:** `systems.edmundlim.LazyMansReminders` (native)
5. Paste secret into Supabase Apple provider

Docs: https://supabase.com/docs/guides/auth/social-login/auth-apple

### D. iOS device / TestFlight

```sh
cd ios && xcodegen generate
open LazyMansReminders.xcodeproj
```

Sign both targets with team `DUU8J39BA7`. On a **physical iPhone** test:

1. Magic link (`lazymansreminders://auth/callback`)
2. Sign in with Apple
3. Google (after A)
4. Tap circle to complete a reminder (leaves list; widget refreshes)
5. Push: add reminder from web while app has registered device token
6. Lock Screen widget (rectangular + inline)
7. Delete account (More menu → Delete permanently)

Then: App Store Connect metadata, privacy URL, support URL, screenshots, paid price US $1.50 / S$2.00, Small Business Program if eligible.

### E. Legal

Templates are live; disclaimer says not legal advice. Confirm `hello@edmundlim.systems` inbox works. Counsel review before paid launch.

---

## 5. Architecture cheat sheet

```
Web (Pages) ──┐
              ├── Supabase Auth (email OTP, Apple id_token / OAuth, Google OAuth)
iOS app ──────┤
              ├── Postgres: reminders, device_tokens (RLS per user)
Widget ───────┘    App Group cache ← ReminderStore session + reminders

INSERT reminders → notify_reminder_push → send-reminder-push → APNs
DELETE account  → delete-account (JWT) → wipe reminders + tokens + auth.users
```

**Key files**

| Area | Path |
|------|------|
| Web UI + OAuth + delete | `web/src/App.tsx`, `web/src/styles.css` |
| Legal | `web/src/LegalPages.tsx` |
| iOS auth | `ios/App/AuthManager.swift` |
| iOS UI / complete / delete | `ios/App/ContentView.swift` |
| Reminder API / markDone | `ios/Shared/ReminderStore.swift` |
| Widget | `ios/Widget/ReminderWidget.swift` |
| Delete account FN | `supabase/functions/delete-account/index.ts` |
| Push FN | `supabase/functions/send-reminder-push/index.ts` |
| Human checklist | `HUMANS.md` |

**Deep links / redirects**

- Web: `${origin}/` (OAuth + magic link)
- iOS: `lazymansreminders://auth/callback`
- Supabase OAuth callback: `https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback`

---

## 6. Deploy commands (if you change more)

```sh
# Edge Function
supabase link --project-ref biwmsxbqrevtjwgsvsmu
supabase functions deploy delete-account
supabase functions deploy send-reminder-push --no-verify-jwt   # only if push FN changes

# Web
cd web
npm ci
npm run deploy   # build + wrangler pages deploy dist -- project lazy-mans-reminders
```

Git: commit on Mac as usual; `main` is the deploy branch.

---

## 7. Known gaps / pitfalls

1. **Zen vs Cursor browser** — agent on Linux could not use Zen cookies; finish Google/Apple Dev in Zen yourself.
2. **Web Apple button** will error until Services ID + secret exist; native Apple can work sooner.
3. **Google on iOS** uses browser sheet, not native Google SDK — fine for v1.
4. **Account linking** — same email via magic link vs Apple/Google may create separate users depending on Supabase settings; test and enable automatic linking if needed.
5. **Tailscale MagicDNS** may fail to resolve `lmr.edmundlim.systems`; use public DNS / `dig @1.1.1.1`.
6. First Xcode run may prompt to register App Group — accept if shown.
7. Legal templates are not lawyer-reviewed.
8. No TestFlight upload yet from this session.

---

## 8. Paste this into a Mac Cursor agent

```text
You are continuing Lazy Man's Reminders on my Mac. Repo: EdmundLimBoEn/lazy-mans-reminders, branch main (pull latest; tip should include 89c0abb).

Read MAC_HANDOFF.md and HUMANS.md first.

Goal: finish launch-blocking auth + device validation using my already-logged-in Zen browser sessions (Google Cloud, Apple Developer, Supabase).

Do in order:
1. git pull --ff-only origin main; confirm Config.xcconfig / web .env.local exist locally (do not commit secrets).
2. Using the browser (prefer my authed Zen/CDP if available, else ask me to Take Control):
   a. Create Google Web OAuth client with redirect https://biwmsxbqrevtjwgsvsmu.supabase.co/auth/v1/callback and origins https://lmr.edmundlim.systems, https://lazy-mans-reminders.pages.dev, http://localhost:5173.
   b. Enable Google in Supabase Auth providers with that client ID/secret.
   c. Enable Sign in with Apple on App ID systems.edmundlim.LazyMansReminders.
   d. Optionally configure web Apple Services ID + secret; Client IDs must list Services ID first, then the iOS App ID.
3. xcodegen + open Xcode; help me run on a physical iPhone and smoke-test: Apple login, Google login, magic link, complete reminder, widget, push, delete account.
4. Update HUMANS.md checkboxes when done. Do not force-push. Do not commit secrets (.env.functions, .p8, Config.xcconfig with secrets).

Constraints: keep the current lock-screen widget (clear glass + marquee). Prefer minimal diffs. Report what you enabled and what still needs me.
```

---

## 9. Session outcomes (this Linux workstream)

| Ask | Outcome |
|-----|---------|
| Legal docs | Shipped + deployed |
| UI off-center / big type / can’t complete on iOS | Fixed in app; web polish deployed |
| Launch extras | Account deletion FN + UI; App Store URL pages |
| Sign in with Apple + Google | Code shipped; Apple provider enabled for native; Google + web Apple secrets still Mac/Zen |
| Deploy/push | `main` pushed; Pages + `delete-account` deployed |

When Mac work is done, friends can use **web Google** and/or **email** immediately; iOS once signed build is on device/TestFlight.
