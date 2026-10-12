create table public.routine_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  text text not null check (char_length(trim(text)) between 1 and 500),
  interval_days integer not null check (interval_days between 1 and 365),
  start_date date not null,
  local_time time not null check (extract(second from local_time) = 0),
  timezone text not null,
  enabled boolean not null default true,
  next_run_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index routine_reminders_due_idx on public.routine_reminders(next_run_at) where enabled;
alter table public.routine_reminders enable row level security;
alter table public.routine_reminders force row level security;
create policy "Users own their routines" on public.routine_reminders
  for all to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
revoke all on public.routine_reminders from anon, authenticated;
grant select, delete on public.routine_reminders to authenticated;
grant insert (user_id, text, interval_days, start_date, local_time, timezone, enabled),
  update (text, interval_days, start_date, local_time, timezone, enabled)
  on public.routine_reminders to authenticated;
alter publication supabase_realtime add table public.routine_reminders;

-- Calendar dates keep the chosen wall-clock time across daylight-saving changes.
create function public.next_routine_run(p_start date, p_time time, p_zone text, p_days integer, p_after timestamptz)
returns timestamptz language plpgsql stable set search_path = '' as $$
declare
  candidate_date date;
  candidate timestamptz;
  elapsed integer;
begin
  if p_days is null or p_days < 1 or p_days > 365 or p_start is null or p_time is null or p_after is null
    or p_zone is null or not exists (select 1 from pg_catalog.pg_timezone_names where name = p_zone) then
    raise exception 'Invalid routine schedule';
  end if;
  elapsed := greatest(0, (p_after at time zone p_zone)::date - p_start);
  candidate_date := p_start + (elapsed / p_days) * p_days;
  candidate := (candidate_date + p_time) at time zone p_zone;
  if candidate <= p_after then
    candidate := (candidate_date + p_days + p_time) at time zone p_zone;
  end if;
  return candidate;
end;
$$;
revoke all on function public.next_routine_run(date, time, text, integer, timestamptz) from public;

create function public.prepare_routine_schedule() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.text := trim(new.text);
  new.next_run_at := public.next_routine_run(new.start_date, new.local_time, new.timezone, new.interval_days, now());
  return new;
end;
$$;
revoke all on function public.prepare_routine_schedule() from public;
-- next_run_at is always server-calculated when a client creates or changes a schedule.
create trigger prepare_routine_schedule before insert or update of text, start_date, local_time, timezone, interval_days, enabled
  on public.routine_reminders for each row execute function public.prepare_routine_schedule();
-- The invoker trigger needs access to the pure calculation function.
grant execute on function public.next_routine_run(date, time, text, integer, timestamptz) to authenticated, service_role;

alter table public.reminders add column routine_id uuid references public.routine_reminders(id) on delete set null;
alter table public.reminders add column routine_fired_at timestamptz;
alter table public.reminders replica identity full;
create unique index reminders_routine_idx on public.reminders(routine_id) where routine_id is not null;

create function public.fire_due_routines() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  routine public.routine_reminders%rowtype;
  fired integer := 0;
  run_time timestamptz := now();
begin
  for routine in select * from public.routine_reminders
    where enabled and next_run_at <= run_time order by next_run_at for update skip locked
  loop
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(routine.user_id::text, 0));
    insert into public.reminders(user_id, text, sort_order, routine_id, routine_fired_at)
    values (routine.user_id, routine.text,
      (select coalesce(min(sort_order), 1) - 1 from public.reminders where user_id = routine.user_id),
      routine.id, routine.next_run_at)
    on conflict (routine_id) where routine_id is not null do update
      set text = excluded.text, sort_order = excluded.sort_order, is_done = false, routine_fired_at = excluded.routine_fired_at;
    update public.routine_reminders set next_run_at = public.next_routine_run(
      routine.start_date, routine.local_time, routine.timezone, routine.interval_days, run_time)
      where id = routine.id;
    fired := fired + 1;
  end loop;
  return fired;
end;
$$;
revoke all on function public.fire_due_routines() from public, anon, authenticated;
grant execute on function public.fire_due_routines() to service_role;

-- Include the previous firing marker so ordinary edits/completion stay silent.
create or replace function public.notify_reminder_push() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
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

create extension if not exists pg_cron;
select cron.schedule('fire-routine-reminders', '* * * * *', 'select public.fire_due_routines()');
