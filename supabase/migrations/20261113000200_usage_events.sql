begin;

-- Daily counters keep churn bounded by users/days/event kinds, not event volume.
create table public.usage_analytics_config (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false
);
insert into public.usage_analytics_config(singleton) values (true);

create table public.usage_daily_counts (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  event text not null check (event in (
    'reminder_created', 'reminder_deleted', 'reminder_completed',
    'agent_token_created', 'agent_token_revoked', 'agent_token_deleted',
    'mcp_list', 'mcp_add', 'mcp_complete', 'mcp_reopen', 'mcp_whoami',
    'agent_oauth_connected'
  )),
  source text not null check (source in ('ios', 'web', 'agent', 'unknown')),
  count bigint not null check (count > 0),
  primary key (user_id, day, event, source)
);
create index usage_daily_counts_day_idx on public.usage_daily_counts(day);
alter table public.usage_analytics_config enable row level security;
alter table public.usage_analytics_config force row level security;
alter table public.usage_daily_counts enable row level security;
alter table public.usage_daily_counts force row level security;
-- No client policies, writes, reads, Realtime publication or public ingest RPC.
revoke all on public.usage_analytics_config, public.usage_daily_counts
  from public, anon, authenticated, service_role;
grant select, update on public.usage_analytics_config to service_role;

create function public.increment_usage_count(p_user_id uuid, p_event text, p_source text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce((select enabled from public.usage_analytics_config where singleton), false) then
    return;
  end if;
  -- Cascading account deletion must neither fail nor recreate analytics.
  insert into public.usage_daily_counts as counts(user_id, day, event, source, count)
  select id, (statement_timestamp() at time zone 'UTC')::date, p_event, p_source, 1
  from auth.users where id = p_user_id
  on conflict (user_id, day, event, source) do update set count = counts.count + 1;
end;
$$;
revoke all on function public.increment_usage_count(uuid,text,text)
  from public, anon, authenticated, service_role;

create function public.usage_request_source() returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  headers jsonb;
  claims jsonb;
  client text;
begin
  -- Set only by the service-only agent add RPC, scoped to its insertion.
  if current_setting('notepad.usage_source', true) = 'agent' then return 'agent'; end if;
  begin
    headers := nullif(current_setting('request.headers', true), '')::jsonb;
    claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  exception when invalid_text_representation then
    return 'unknown';
  end;
  client := headers ->> 'x-notepad-client';
  if client = 'agent' and claims ->> 'role' = 'service_role' then return 'agent'; end if;
  if client in ('ios', 'web') then return client; end if;
  return 'unknown';
end;
$$;
revoke all on function public.usage_request_source() from public, anon, authenticated, service_role;

create function public.capture_usage_change() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  event_name text;
  owner_id uuid;
begin
  if not coalesce((select enabled from public.usage_analytics_config where singleton), false) then
    return null;
  end if;
  owner_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
  if tg_table_name = 'reminders' then
    if tg_op = 'INSERT' then event_name := 'reminder_created';
    elsif tg_op = 'DELETE' then event_name := 'reminder_deleted';
    elsif not old.is_done and new.is_done then event_name := 'reminder_completed';
    end if;
  elsif tg_table_name = 'agent_tokens' then
    if tg_op = 'INSERT' then event_name := 'agent_token_created';
    elsif tg_op = 'DELETE' then event_name := 'agent_token_deleted';
    elsif old.revoked_at is null and new.revoked_at is not null then event_name := 'agent_token_revoked';
    end if;
  end if;
  if event_name is not null then
    perform public.increment_usage_count(owner_id, event_name, public.usage_request_source());
  end if;
  return null;
end;
$$;
revoke all on function public.capture_usage_change() from public, anon, authenticated, service_role;
create trigger usage_reminder_change after insert or update or delete on public.reminders
  for each row execute function public.capture_usage_change();
create trigger usage_agent_token_change after insert or update or delete on public.agent_tokens
  for each row execute function public.capture_usage_change();

-- Worker-only events cover OAuth grants (stored in Cloudflare) and read-only MCP calls.
create function public.record_agent_usage(p_user_id uuid, p_event text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce((select enabled from public.usage_analytics_config where singleton), false) then return; end if;
  if p_event is null or p_event not in ('mcp_list', 'mcp_add', 'mcp_complete',
      'mcp_reopen', 'mcp_whoami', 'agent_oauth_connected') then
    raise invalid_parameter_value using message = 'Invalid analytics event';
  end if;
  perform public.increment_usage_count(p_user_id, p_event, 'agent');
end;
$$;
revoke all on function public.record_agent_usage(uuid,text) from public, anon, authenticated;
grant execute on function public.record_agent_usage(uuid,text) to service_role;

-- Reports remain readable by the service role after collection is disabled.
create function public.usage_daily_report(p_from date, p_to date)
returns table(user_id uuid, day date, created bigint, deleted bigint, completed bigint)
language sql stable security definer set search_path = '' as $$
  select user_id, day,
    coalesce(sum(count) filter (where event = 'reminder_created'), 0)::bigint,
    coalesce(sum(count) filter (where event = 'reminder_deleted'), 0)::bigint,
    coalesce(sum(count) filter (where event = 'reminder_completed'), 0)::bigint
  from public.usage_daily_counts where day between p_from and p_to
  group by user_id, day order by day desc, 3 desc, 4 desc, user_id;
$$;
create function public.usage_source_report(p_from date, p_to date)
returns table(day date, source text, event text, events bigint, users bigint)
language sql stable security definer set search_path = '' as $$
  select day, source, event, sum(count)::bigint, count(distinct user_id)
  from public.usage_daily_counts where day between p_from and p_to
  group by day, source, event order by day desc, source, event;
$$;
create function public.usage_abuse_report(
  p_day date default (now() at time zone 'UTC')::date,
  p_created_threshold integer default 100,
  p_deleted_threshold integer default 100,
  p_stored_threshold integer default 500
)
returns table(user_id uuid, created bigint, deleted bigint, stored bigint, active bigint,
  high_creates boolean, high_deletes boolean, high_stored boolean)
language sql stable security definer set search_path = '' as $$
  with daily as (select * from public.usage_daily_report(p_day, p_day)),
  inventory as (
    select user_id, count(*) as stored, count(*) filter (where not is_done) as active
    from public.reminders group by user_id
  ), combined as (
    select coalesce(d.user_id, i.user_id) as user_id,
      coalesce(d.created, 0) as created, coalesce(d.deleted, 0) as deleted,
      coalesce(i.stored, 0) as stored, coalesce(i.active, 0) as active
    from daily d full join inventory i using(user_id)
  )
  select *, created >= greatest(p_created_threshold, 1),
    deleted >= greatest(p_deleted_threshold, 1), stored >= greatest(p_stored_threshold, 1)
  from combined order by created desc, deleted desc, stored desc, user_id;
$$;
revoke all on function public.usage_daily_report(date,date), public.usage_source_report(date,date),
  public.usage_abuse_report(date,integer,integer,integer) from public, anon, authenticated;
grant execute on function public.usage_daily_report(date,date), public.usage_source_report(date,date),
  public.usage_abuse_report(date,integer,integer,integer) to service_role;

-- Keep today plus the preceding 89 UTC dates. Cleanup runs even when disabled.
create function public.cleanup_usage_counts(p_batch_size integer default 10000)
returns integer language plpgsql security definer set search_path = '' as $$
declare affected integer;
begin
  with expired as (
    select ctid from public.usage_daily_counts
    where day < (statement_timestamp() at time zone 'UTC')::date - 89
    order by day limit least(greatest(p_batch_size, 1), 10000) for update skip locked
  ) delete from public.usage_daily_counts where ctid in (select ctid from expired);
  get diagnostics affected = row_count;
  return affected;
end;
$$;
revoke all on function public.cleanup_usage_counts(integer) from public, anon, authenticated;
grant execute on function public.cleanup_usage_counts(integer) to service_role;
-- pg_cron is already required by the routine-reminder migration.
select cron.schedule('cleanup-usage-counts', '17 * * * *', 'select public.cleanup_usage_counts();');

-- Preserve quota, owner lock and append ordering; scope attribution to the insert.
-- Recover agent append ordering when the active board reaches the integer maximum.
create or replace function public.add_agent_reminder(p_user_id uuid, p_text text)
returns table (
  id uuid,
  user_id uuid,
  text text,
  sort_order integer,
  is_done boolean,
  created_at timestamptz,
  completed_at timestamptz,
  capacity_maximum integer,
  active_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  trimmed text := trim(p_text);
  cap_max integer;
  active integer;
  next_order integer;
  inserted public.reminders%rowtype;
  previous_source text := current_setting('notepad.usage_source', true);
begin
  if p_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if char_length(trimmed) < 1 or char_length(trimmed) > 500 then
    raise exception 'LMR_INVALID_TEXT';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user_id::text, 0));

  select least(16, greatest(1, coalesce(
    (select prefs.max_lines from public.lock_screen_prefs as prefs where prefs.user_id = p_user_id),
    6
  )))
  into cap_max;

  select count(*) into active
  from public.reminders as reminders
  where reminders.user_id = p_user_id and reminders.is_done = false;

  if active >= cap_max then
    raise exception 'LMR_CAPACITY_REACHED'
      using errcode = 'P0001',
            detail = cap_max::text;
  end if;

  select max(reminders.sort_order) into next_order
  from public.reminders as reminders
  where reminders.user_id = p_user_id and reminders.is_done = false;

  if next_order = 2147483647 then
    -- Reclaim integer headroom under the owner lock, preserving board order.
    with ranked as (
      select reminders.id,
        (row_number() over (order by reminders.sort_order, reminders.created_at, reminders.id) - 1)::integer as position
      from public.reminders as reminders
      where reminders.user_id = p_user_id and reminders.is_done = false
    )
    update public.reminders as reminders
    set sort_order = ranked.position
    from ranked
    where reminders.id = ranked.id;

    next_order := active;
  else
    next_order := coalesce(next_order, -1) + 1;
  end if;

  perform set_config('notepad.usage_source', 'agent', true);
  insert into public.reminders (user_id, text, sort_order)
  values (p_user_id, trimmed, next_order)
  returning * into inserted;
  perform set_config('notepad.usage_source', coalesce(previous_source, ''), true);

  return query
  select
    inserted.id,
    inserted.user_id,
    inserted.text,
    inserted.sort_order,
    inserted.is_done,
    inserted.created_at,
    inserted.completed_at,
    cap_max,
    active + 1;
end;
$$;

revoke all on function public.add_agent_reminder(uuid, text) from public, anon, authenticated;
grant execute on function public.add_agent_reminder(uuid, text) to service_role;

commit;
