# Enable usage counters (Jeremy)

Prepared configuration only: nothing in this change has been applied live. The
repository now sets the nonsecret Worker var `USAGE_ANALYTICS_ENABLED` to `"true"`.
Applying the new migration starts iOS/web mutation counting immediately, before
any Worker deployment. MCP tool/OAuth telemetry requires both gates; database
triggers can already count agent reminder/token mutations with the DB gate alone.
There is no historical backfill. Coordinate the disclosure/manifest readiness
identified in [the analytics plan](plan.md) before the live enablement.

## Live enablement

1. Open the [SQL Editor for project biwmsxbqrevtjwgsvsmu](https://supabase.com/dashboard/project/biwmsxbqrevtjwgsvsmu/sql/new).
   Confirm the project reference and use the database owner (`postgres`) role.
   Confirm PR #253's tables/functions exist. Apply
   `supabase/migrations/20261113000300_enable_usage_analytics.sql` through the
   normal migration release, **or** run this exact equivalent SQL in the editor:

   ```sql
   begin;
   insert into public.usage_analytics_config(singleton, enabled)
   values (true, true)
   on conflict (singleton) do update set enabled = excluded.enabled;
   commit;
   select singleton, enabled from public.usage_analytics_config;
   ```

   Expect one row, `true, true`. The SQL Editor alternative changes data without
   recording a Supabase migration version; a later normal migration application
   is idempotent while enabled, but will re-enable collection after a rollback.
   Do not bulk-apply unrelated pending migrations just to enable this switch.

2. From an approved checkout containing this change, confirm `mcp/wrangler.jsonc`
   names `lazy-mans-reminders-mcp` and contains
   `"USAGE_ANALYTICS_ENABLED": "true"` under `vars`. With the existing authorized
   Cloudflare login, run:

   ```sh
   cd mcp
   npm ci
   npx wrangler whoami
   npm run deploy
   ```

   Check `whoami` shows the account owning the Worker before deploying. This
   redeploys the MCP Worker with the nonsecret var; it changes no secrets.
   In Cloudflare, verify the active deployment of `lazy-mans-reminders-mcp` has
   the text variable `USAGE_ANALYTICS_ENABLED=true` and both custom domains
   `np-mcp.sillyapps.co` and `lmr-mcp.edmundlim.systems`.

## Verify

As DB owner in the same project's SQL Editor, capture a baseline using UTC dates:

```sql
select singleton, enabled from public.usage_analytics_config;
select * from public.usage_daily_report(
  (now() at time zone 'UTC')::date, (now() at time zone 'UTC')::date);
select * from public.usage_source_report(
  (now() at time zone 'UTC')::date, (now() at time zone 'UTC')::date);
```

Use a dedicated synthetic account with board capacity available. In the deployed
web app, create one reminder, mark it complete once, then delete it. Rerun the
reports: that account's daily `created`, `completed`, and `deleted` should each
increase by one, with `web` source buckets. Repeat on iOS to check `ios` attribution
if desired; older clients can report `unknown`. These events remain counted after
the reminder is deleted.

Connect an authenticated MCP client for that test account to
`https://np-mcp.sillyapps.co/mcp` (or `https://lmr-mcp.edmundlim.systems/mcp`).
Invoke the `list_reminders` tool once and rerun `usage_source_report`: expect
`source='agent'`, `event='mcp_list'` to increase by one. Repeat on the other host
if verifying both routes. A completed new OAuth authorization should add
`agent_oauth_connected`; token refresh alone will not. Worker telemetry is best
effort, so allow the request to finish and investigate missing increments.
`usage_daily_report` reports reminder mutations; use `usage_source_report` for
MCP/OAuth counts. Do not treat a SQL-only ingest probe as Worker verification.

## Rollback

First run this as DB owner in the same Supabase SQL Editor to stop all collection
immediately (it also safely handles a missing singleton):

```sql
begin;
insert into public.usage_analytics_config(singleton, enabled)
values (true, false)
on conflict (singleton) do update set enabled = excluded.enabled;
commit;
select singleton, enabled from public.usage_analytics_config;
```

Expect `true, false`. Remove the `USAGE_ANALYTICS_ENABLED` entry from
`mcp/wrangler.jsonc` `vars` in the rollback checkout, then run `npm run deploy`
from `mcp` using the same Cloudflare account. Verify the active Worker's variable
is absent. Keep that removal in the deployment source so the next deploy does
not restore the flag. With the DB flag off, Worker calls cannot increment counts
while the rollback deployment is in progress.

Repeat a synthetic operation and confirm the counters do not increase. Reports
and retention cleanup continue working. Do not drop tables or rewrite the
original migration. If the enable migration has not yet been recorded as applied,
ensure the release process will not apply it later and unintentionally re-enable
collection.
