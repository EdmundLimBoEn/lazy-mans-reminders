# Human actions

- [ ] **DNS for `lmr.edmundlim.systems`** — Pages domain is registered, but the zone CNAME is missing (Wrangler OAuth cannot write DNS). In Cloudflare → `edmundlim.systems` → DNS, add:
  - Type: `CNAME`
  - Name: `lmr`
  - Target: `lazy-mans-reminders.pages.dev`
  - Proxy: **Proxied** (orange cloud)
  Then confirm https://lmr.edmundlim.systems loads and the Pages domain status becomes `active`.
- [ ] **Apple Developer identifiers** — Create App ID `systems.edmundlim.LazyMansReminders`, widget ID `systems.edmundlim.LazyMansReminders.Widget`, App Group `group.systems.edmundlim.LazyMansReminders`. Enable Push Notifications on the app ID and App Groups on both.
- [ ] **APNs + webhook** — Create APNs `.p8`, fill `supabase/.env.functions`, `supabase secrets set --env-file supabase/.env.functions`, and create the `public.reminders` INSERT webhook with `x-webhook-secret`.
- [ ] **Device test** — Open `ios/LazyMansReminders.xcodeproj`, sign both targets with team `DUU8J39BA7`, run on a physical iPhone (magic link, push, lock-screen widgets). No build was run during setup.
