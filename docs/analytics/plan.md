# Analytics and abuse monitoring

Evaluation date: 13 November 2026. Recommendation: **use daily Supabase counters**, disabled by default. This uses the existing database and Worker credentials, adds no account or secret, and has no new analytics processor. It can stay within the existing free allocation; it is not a promise of unlimited free database capacity. No deployment or remote migration is part of this change.

## What the repository already records

Reviewed `README.md`, `HUMANS.md`, `MAC_HANDOFF.md`, the migrations through `20261109000300`, MCP authentication/board/OAuth paths, web Supabase/board/legal code, and iOS reminder storage/privacy manifest.

| Existing data/path | What it tells us; limitations |
| --- | --- |
| `reminders` | Owner UUID, text, order, completion state, creation/update/completion times, routine linkage/firing time. There is no separate thread/task table: a “thread” here means a reminder row. DELETE loses the row; no durable historical deletion count exists. |
| Completed-reminder cleanup | `delete_old_completed_reminders()` removes rows completed over seven days ago, requested on board load and optionally by cron. Deletes are not necessarily deliberate user actions. |
| `agent_tokens` | Owner, name, creation/last-used/revocation timestamps and token hash. MCP PAT authentication touches `last_used_at` best effort; this is neither a historical event stream nor OAuth coverage. Never copy hashes or token names into analytics. |
| MCP OAuth | Grants and authorization state live in Cloudflare storage, not `agent_tokens`. Successful `completeAuthorization()` is a connection signal, not evidence of later tool use. |
| `add_agent_reminder` / MCP board commands | Service-only add RPC serializes per owner and clamps capacity to the phone preference within 1–16. MCP also lists, completes, reopens and answers `whoami`; client-only analytics would miss all these. |
| Quotas and budgets | Hard limit: 16 active reminders, 50 routines, 20 active personal agent tokens; shared database budget: 600 row mutations/minute/user. Completed rows can accumulate; high create/delete churn can occur under the active limit. `user_write_budgets` keeps the current window only. Worker rate limits are separate. |
| Routines, devices and preferences | Server routines can create/reactivate reminders; device registration establishes push capability, not active iOS use. A reminder's text prefix or existence of a device token is not a trustworthy source classifier. |
| Source | No explicit web/iOS marker in the reviewed clients. Web uses `web/src/supabase.ts`; reminder operations on iOS use direct `URLRequest`s in `ios/Shared/ReminderStore.swift`, not just the auth Supabase client. |
| Privacy | Manifest lists seven linked, nontracking types for App Functionality, including User ID, Device ID and Other Diagnostic Data; no Product Interaction or Analytics purpose. Policy describes operational logs and seven-day completed cleanup, and says no third-party product analytics or optional analytics cookies. |

The supplied task names `app.notepads.dev`; repository guidance still names `np.sillyapps.co` and its aliases. No hostname changes were made; Edmund should confirm the publication host when updating policy copy.

## Options and goal coverage

PostHog Cloud currently includes **1 million analytics events/month**, with no card needed for the free allowance. Beyond that, usage can become paid; confirm account limits and billing controls before enabling it. US and EU ingestion are available, and PostHog documents EU storage in Frankfurt. It requires a new account/project and project API key. That ingestion key is intended for clients (not an admin secret), but still adds new configuration. Sources: [pricing](https://posthog.com/pricing), [storage](https://posthog.com/docs/privacy/data-storage), [iOS setup](https://posthog.com/docs/libraries/ios).

| Goal | A: PostHog | B: In-house Supabase counters |
| --- | --- | --- |
| Deleted reminders/tasks | Explicit post-success client event captures some deletes; authoritative coverage needs server instrumentation/outbox. No recovery of historical deletes. | AFTER DELETE preserves counts for committed deletions, including direct REST, maintenance and service writes. Counts only, not deleted IDs or text. No backfill. |
| Very heavy users / abuse | Dashboards, cohorts and alert integrations; client events alone can be suppressed or fabricated. Requires trustworthy server signals for enforcement. | Daily per-owner creates/deletes and current stored/active inventory; configurable review flags, existing hard quotas remain enforcement. Handles create/delete churn. |
| Agent connections / MCP | Requires additional Worker/server events: neither iOS nor JS SDK sees MCP on its own. | Token create/revoke/delete triggers; successful OAuth authorization and authenticated tool invocation counters from Worker. |
| Web vs iOS | `posthog-js` and `posthog-ios` can measure sessions/screens/funnels as well as explicit events. | Measures reminder mutations by optional client header. Older/unmarked/system traffic is `unknown`. No pageviews, app launches or read-only app usage. |
| Privacy | Additional analytics processor, identifiers and SDK/network metadata; defaults/autocapture/replay require careful restriction to avoid content collection. | Account-linked counts with existing Supabase processor; no new third party, content, reminder ID, IP, device ID, token ID or name stored in counters. Still personal usage data. |
| Cost / effort | Fast dashboard setup, but native + web + Worker integrations, account setup, identity/deletion handling, SDK updates and privacy work. Rough estimate: several days plus Mac QA. | SQL reports instead of a dashboard; migration, source markers, Worker hooks and SQL tests. Rough estimate: 1–3 engineering days plus staged validation/privacy work. |
| Maintenance / accuracy | Vendor handles analytics UI/infrastructure; maintain SDKs, spend caps, data minimization and deletion integration. Browser blockers, offline queues and crashes can lose client events. | Maintain SQL/indexes/cron and monitor storage. Transactional triggers cannot be bypassed by blocking an analytics endpoint while still committing the underlying write; privileged DB operators can disable triggers. Worker events remain best effort. |

SDK references: [posthog-js](https://posthog.com/docs/libraries/js), [posthog-ios](https://posthog.com/docs/libraries/ios). No SDK is added here.

**Choose B.** Append-only per-event records could preserve exact times and deleted IDs, but grow with abusive traffic itself. Daily counters answer the current questions with less retained information and fewer rows. PostHog would add funnels, retention cohorts, session/screen analysis and a usable dashboard later. If adopted, retain server counters as the abuse source of truth; explicitly allowlist events, disable replay/autocapture initially, exclude reminder content and configure identity reset/account erasure. Do not silently forward these counters to another vendor.

## Implemented minimal design

Migration: `supabase/migrations/20261113000200_usage_events.sql` (new, after the latest existing migration).

- `usage_analytics_config`: singleton `enabled=false`. Missing row also means off. Only service role/DB owner can change it.
- `usage_daily_counts`: primary key `(user_id, day, event, source)` plus positive bigint count; atomic UPSERT increments. UTC day is derived from statement time, not a client timestamp. FK to `auth.users` cascades on account deletion.
- SECURITY DEFINER functions have empty search paths and explicit grants. RLS is enabled/forced with no user policies; anon/authenticated have no table or function access. Even service role has no direct counter-table grants; it uses the reporting/ingest/cleanup RPCs. No Realtime publication.
- Reminder AFTER triggers count inserts, deletes, and false→true completion transitions. Reordering, editing, repeated completion and upsert UPDATE branches do not invent creations. A later real completion after reopening counts again. Insert-already-completed counts as creation only.
- Token triggers count mint, first revocation and deletion. `last_used_at` updates do not count as tool usage. Token lifecycle source identifies where management happened (often web), not an agent executing a tool.
- `add_agent_reminder` retains its original signature, lock, quota and append logic; it sets/restores transaction-local attribution around its insert, so even direct service calls are agent additions. Other MCP writes carry a service-role-only `agent` header.
- `record_agent_usage` accepts only six fixed Worker event names. `mcp_list/add/complete/reopen/whoami` count authenticated, schema-valid handler invocations, including business failures; they are not successful mutation counts. OAuth connection counts a completed grant authorization, not a unique currently connected agent. Denials, token exchanges/refreshes, OAuth revocations, transport initialization and rejected unauthenticated calls are not counted. Existing grant APIs remain the source for current connections.
- Worker telemetry requires `USAGE_ANALYTICS_ENABLED=true` **and** the database flag. The nonsecret Worker flag defaults unset/off and avoids extra calls entirely. Enabled telemetry waits at most about one second per request using abort, ignores errors and does not retry/log payloads. Grant creation and telemetry are separate transactions; undercounts are possible on failure, and retries are new invocations. No exactly-once claim.

### Source and deletion semantics

`x-notepad-client: web` is added to the shared web client; `ios` to iOS ReminderStore requests, including cleanup; `agent` to the MCP service client. The database accepts `agent` only with a verified PostgREST service-role claim, except the internal agent-add context. Web/iOS hints are caller supplied and spoofable: use them for approximate platform comparisons, never authorization or sanctions. No user-agent parsing, text-prefix parsing, persistent creation-source column or new JWT claim is invented. The source describes the request performing a change, not where the reminder was originally created. Native background/Shortcuts work uses `ios`, so this is not foreground screen usage.

Old clients and cron/admin requests without markers are `unknown`; malformed/unsupported headers also fall back to unknown. Routine reactivation is not a new creation. Routine insertions contribute to counts, often unknown. All deletion reasons share `reminder_deleted`: seven-day cleanup initiated by web/iOS is attributed to that initiating platform. Account teardown may temporarily count explicit child deletes, then the auth-user FK erases that account's counters; cascade deletes cannot recreate them. These counters are not a manual-delete audit or a forensic archive. A later reason enum would need explicit, trusted context in each cleanup/scheduler path.

### Reports, thresholds and retention

Only service role (or DB owner) can run:

```sql
select * from public.usage_daily_report(current_date - 6, current_date);
select * from public.usage_daily_report(current_date, current_date)
order by deleted desc;
select * from public.usage_source_report(current_date - 6, current_date);
select * from public.usage_abuse_report()
where high_creates or high_deletes or high_stored;
```

Reports use inclusive date ranges; pass explicit UTC dates if the SQL session timezone differs. Source output includes event kind and distinct participating accounts; one account may appear in several sources/events, so do not sum `users` into a global unique count. Daily report ranks creation counts by day; deletion ranking can be requested as above. Abuse report compares one UTC day's creates/deletes to defaults **100/100**, and current total stored reminders to **500**, including accounts with no collected events. Threshold arguments are adjustable and clamped to at least one. Inventory is current, even for a historical report date. These are review signals, not proof of abuse or automatic bans. Start with a week of observations and inspect cleanup/routine effects before changing thresholds. No notification service or alerts UI is introduced.

Retain today plus the previous 89 UTC dates. Existing `pg_cron` runs `cleanup_usage_counts()` hourly at minute 17, deleting up to 10,000 oldest eligible rows with SKIP LOCKED; repeat manually to drain a backlog. Cleanup still runs when collection is disabled. Outages/backlogs can extend retention: verify cron success and oldest retained day operationally. This bounds logical history, not backups/WAL or physical disk size; normal vacuum and the existing provider backup policy still apply.

For scale, 1,000 participating users × 90 days × 4 populated daily buckets is 360,000 rows before indexes. Actual combinations vary. Daily aggregation bounds rows per user/day/event/source but does not prevent a large number of accounts or expensive repeated writes. Monitor table/index size, database CPU and cron lag in existing Supabase tools; disable collection if it consumes too much free capacity. Transactional counters add latency and can reject a write if the database counter operation fails; the flag is the operational escape hatch. There is no exception-swallowing around transactional counts that would silently falsify successful-write totals.

## Privacy work before enabling collection

Both approaches need disclosure review. Account UUID aggregation is **linked to the user**, not anonymization. Under Apple's categories, these interaction counts map to **Usage Data → Product Interaction** and the owner UUID to **Identifiers → User ID**. Analytics applies to platform/product measurement; App Functionality applies to abuse prevention. Existing User ID purposes need expansion as appropriate. This mapping is an engineering assessment for Edmund to confirm against actual enabled behavior. [Apple privacy categories/purposes](https://developer.apple.com/app-store/app-privacy-details/).

For either option, before collecting from iOS, update App Store Connect declarations and `ios/Shared/PrivacyInfo.xcprivacy`: add `NSPrivacyCollectedDataTypeProductInteraction`, linked=true, tracking=false, and `NSPrivacyCollectedDataTypePurposeAnalytics` / `NSPrivacyCollectedDataTypePurposeAppFunctionality` for the applicable uses. Add Analytics to the existing User ID entry when used for these reports. For PostHog, audit actual SDK identifiers and defaults; Device ID and other types may also need revised declarations. Inspect the aggregate privacy report on a Mac. The manifest is intentionally unchanged while this feature is off. [Apple manifest guidance](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest).

Neither design inherently tracks across other companies' apps/sites or uses IDFA. ATT permission is not required for that nontracking setup; adding a third-party SDK alone does not establish tracking. Do not confuse ATT with general legal consent: any consent/notice requirements depend on jurisdiction, purpose and SDK storage practices, especially optional web analytics. No consent dialog is added by this implementation. [Apple tracking definition](https://developer.apple.com/app-store/app-privacy-details/).

Edmund owns every published word. Suggested copy he can tweak before enabling collection (no published policy/UI text changed here); the PostHog line applies only if that option is adopted later:

| Location / decision | Copy |
| --- | --- |
| Privacy policy collection and purpose: owner-linked daily interaction counts, platform hints, product measurement and abuse review | We keep daily usage counts linked to your account and the reported platform in Supabase to understand usage and prevent abuse, without reminder text or sharing with a separate analytics provider. |
| Retention/deletion: rolling 90 UTC dates, cron backlog caveat, erasure on successful account deletion, provider backups | We keep counts for today and the previous 89 UTC dates, though cleanup delays may extend this; successful account deletion removes them from the active service, while backups follow the providers’ retention settings. |
| Access/export: current client export does not include admin-only analytics; provide an authenticated support-mediated access process without exposing cross-user reports | Daily usage counts are not included in Download my data; contact support for a copy of your own counts after we verify your account. |
| App Store privacy declarations and any explanatory release text | Account-linked usage counts and user IDs are used for analytics and app functionality, including abuse prevention, and are not used for tracking. |
| If PostHog later: replace “no third-party product analytics” claim; identify processor/region, identifiers, retention/deletion and any storage/consent choice | If we add PostHog, we will first explain its processing role, storage region, identifiers, retention and deletion rules, and any storage or consent choices. |

The existing “no third-party product analytics” statement remains consistent with the chosen Supabase-only option, but does not substitute for disclosure of new first-party product analytics.

## Rollout and validation handoff

1. Review this implementation and privacy decisions. Keep both flags off until Edmund's policy/label/manifest changes are ready. Do not apply remotely as part of this task.
2. Run the disposable SQL CI job. It now applies the migration, runs `supabase/tests/usage_events.sql`, and reruns agent append/quota tests after the RPC replacement. The SQL tests roll back fixtures and stub push delivery.
3. Compile/test iOS on a Mac; verify the custom header on create/complete/cleanup and browser CORS acceptance in staging. No Xcode is available on this Linux host. Source attribution can lag until upgraded clients are installed.
4. In a separately authorized deployment, migrate first, release the header/Worker changes, and verify service-only RPC access. Enable the database row only when ready; optionally set the Worker nonsecret flag to `true` for tool/OAuth counts. The database flag is the master collection gate.
5. With synthetic accounts, compare known create/complete/delete counts, PAT lifecycle, OAuth connection, MCP listing and unknown-source writes. Confirm account erasure and cleanup job operation. Check query latency/storage before wider use.
6. Rollback behavior: set `usage_analytics_config.enabled=false`, unset the Worker flag; reports and retention keep working. Do not drop counters or rewrite old migrations to disable collection.

Local verification results are recorded in `/workspace/codex-sprint/np101/analytics.summary.md`. Remaining scope decisions: whether counts satisfy “know deleted threads” (individual IDs/text deliberately absent), whether launches/read-only app use are needed, and whether 90 days / initial abuse thresholds are appropriate. These do not block the disabled implementation.
