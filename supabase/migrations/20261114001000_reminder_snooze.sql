begin;

alter table public.reminders add column snoozed_until timestamptz;
create index reminders_snoozes_due on public.reminders(snoozed_until, id)
  where snoozed_until is not null;

-- Validate on writes, not with a time-dependent CHECK. Completion always clears snooze.
create function public.normalize_reminder_snooze() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_done then
    new.snoozed_until := null;
  elsif new.snoozed_until > now() + interval '48 hours' then
    raise exception 'Snooze must be within 48 hours.';
  end if;
  return new;
end;
$$;
revoke all on function public.normalize_reminder_snooze() from public, anon, authenticated;
create trigger aaa_normalize_reminder_snooze before insert or update on public.reminders
  for each row execute function public.normalize_reminder_snooze();

create or replace function public.enforce_reminder_quota() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.is_done or new.snoozed_until > now() then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if new.user_id = old.user_id and not old.is_done
      and (old.snoozed_until is null or old.snoozed_until <= now()) then
      return new;
    end if;
  end if;

  -- Share the agent/scheduler lock so every writer counts after earlier writes commit.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 0));
  -- MAX_ACTIVE_REMINDERS in web/src/lib/reminders.ts; phone display limits may be lower.
  if (select count(*) from public.reminders where user_id = new.user_id and not is_done
      and (snoozed_until is null or snoozed_until <= now())) >= 16 then
    -- BEFORE INSERT also runs for ON CONFLICT: refreshing a pending routine or
    -- upserting an existing pending ID may consume no slot, including when snoozed. The UPDATE
    -- trigger below still checks any subsequent activation/ownership change.
    if tg_op = 'INSERT' and exists (
      select 1 from public.reminders
      where user_id = new.user_id and not is_done
        and (id = new.id or routine_id = new.routine_id)
    ) then
      return new;
    end if;
    raise exception using errcode = 'P0001',
      message = 'You can have at most 16 active reminders. Complete or delete a reminder before adding another.',
      detail = '16 LMR_CAPACITY_REACHED';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_reminder_quota() from public, anon, authenticated;

-- Include snooze changes so an early manual unsnooze cannot bypass capacity.
drop trigger reminders_enforce_quota on public.reminders;
create trigger reminders_enforce_quota
  before insert or update of is_done, user_id, snoozed_until on public.reminders
  for each row execute function public.enforce_reminder_quota();

create or replace function public.reorder_reminders(p_ids uuid[])
returns setof public.reminders
language plpgsql
security invoker
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  active_count integer;
begin
  if owner_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(owner_id::text, 0));
  perform 1 from public.reminders
    where user_id = owner_id and is_done = false and (snoozed_until is null or snoozed_until <= now()) for update;

  select count(*) into active_count from public.reminders
    where user_id = owner_id and is_done = false and (snoozed_until is null or snoozed_until <= now());
  if p_ids is null
    or cardinality(p_ids) <> active_count
    or (select count(distinct id) from unnest(p_ids) as requested(id)) <> active_count
    or exists (
      select 1 from unnest(p_ids) as requested(id)
      where not exists (
        select 1 from public.reminders
        where reminders.id = requested.id and user_id = owner_id and is_done = false and (snoozed_until is null or snoozed_until <= now())
      )
    ) then
    raise exception 'The board changed. Refresh and try reordering again.';
  end if;

  update public.reminders as reminder
    set sort_order = requested.position - 1
    from unnest(p_ids) with ordinality as requested(id, position)
    where reminder.id = requested.id and reminder.user_id = owner_id and reminder.is_done = false and (reminder.snoozed_until is null or reminder.snoozed_until <= now());

  return query select * from public.reminders
    where user_id = owner_id and is_done = false and (snoozed_until is null or snoozed_until <= now())
    order by sort_order, created_at, id;
end;
$$;

revoke all on function public.reorder_reminders(uuid[]) from public, anon;
grant execute on function public.reorder_reminders(uuid[]) to authenticated;

-- Preserve the existing agent attribution and append-order behavior.
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
  where reminders.user_id = p_user_id and reminders.is_done = false
    and (reminders.snoozed_until is null or reminders.snoozed_until <= now());

  if active >= cap_max then
    raise exception 'LMR_CAPACITY_REACHED'
      using errcode = 'P0001',
            detail = cap_max::text;
  end if;

  select max(reminders.sort_order) into next_order
  from public.reminders as reminders
  where reminders.user_id = p_user_id and reminders.is_done = false
    and (reminders.snoozed_until is null or reminders.snoozed_until <= now());

  if next_order = 2147483647 then
    -- Reclaim integer headroom under the owner lock, preserving board order.
    with ranked as (
      select reminders.id,
        (row_number() over (order by reminders.sort_order, reminders.created_at, reminders.id) - 1)::integer as position
      from public.reminders as reminders
      where reminders.user_id = p_user_id and reminders.is_done = false
        and (reminders.snoozed_until is null or reminders.snoozed_until <= now())
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

-- Snooze-only changes must survive the existing no-op push suppression.
create or replace function public.notify_reminder_push() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- set_updated_at runs even for no-op updates. Ignore that timestamp while
  -- retaining board order, completion, and routine firing changes.
  if tg_op = 'UPDATE' then
    if row(old.id, old.user_id, old.text, old.sort_order, old.is_done,
           old.created_at, old.completed_at, old.routine_id, old.routine_fired_at, old.snoozed_until)
      is not distinct from
       row(new.id, new.user_id, new.text, new.sort_order, new.is_done,
           new.created_at, new.completed_at, new.routine_id, new.routine_fired_at, new.snoozed_until) then
      return null;
    end if;
  end if;
  perform public.request_reminder_push(jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', case when TG_OP = 'DELETE' then to_jsonb(OLD) else to_jsonb(NEW) end,
    'old_record', case when TG_OP = 'INSERT' then null else to_jsonb(OLD) end
  ));
  return null;
end;
$$;
revoke all on function public.notify_reminder_push() from public, anon, authenticated;

-- Bound each tick; skip locked reminders and retry budget/lock failures next minute.
-- The ordinary UPDATE fires send_reminder_push and the shared write-budget trigger.
create function public.clear_expired_snoozes() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  candidate record;
  affected integer;
  cleared integer := 0;
  deferred_owners uuid[] := '{}'::uuid[];
  previous_lock_timeout text := current_setting('lock_timeout');
begin
  perform set_config('lock_timeout', '100ms', true);
  for candidate in
    select id, user_id from public.reminders
    where snoozed_until <= now()
    order by snoozed_until, id limit 100
  loop
    if candidate.user_id = any(deferred_owners) then continue; end if;
    begin
      -- Take row locks inside the subtransaction so failed writes release them.
      perform 1 from public.reminders where id = candidate.id and snoozed_until <= now()
        for update skip locked;
      if not found then continue; end if;
      update public.reminders set snoozed_until = null
      where id = candidate.id and snoozed_until <= now();
      get diagnostics affected = row_count;
      cleared := cleared + affected;
    exception when lock_not_available then
      deferred_owners := array_append(deferred_owners, candidate.user_id);
      continue;
    when sqlstate 'P0001' then
      if sqlerrm <> 'rate_limited' then raise; end if;
      deferred_owners := array_append(deferred_owners, candidate.user_id);
      continue;
    end;
  end loop;
  perform set_config('lock_timeout', previous_lock_timeout, true);
  return cleared;
end;
$$;
revoke all on function public.clear_expired_snoozes() from public, anon, authenticated;

select cron.schedule('clear-expired-reminder-snoozes', '* * * * *',
  'select public.clear_expired_snoozes();');

commit;
