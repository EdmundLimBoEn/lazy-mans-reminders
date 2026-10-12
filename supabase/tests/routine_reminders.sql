-- Run after migrations against a disposable database. All fixtures roll back.
begin;
-- Capture real trigger payloads without making network requests.
create temporary table routine_push_payloads(payload jsonb);
create or replace function public.request_reminder_push(payload jsonb) returns bigint
language plpgsql as $$ begin
  insert into routine_push_payloads values (payload);
  return 1;
end $$;
drop trigger if exists send_reminder_push on public.reminders;
create trigger send_reminder_push after insert or update or delete on public.reminders
  for each row execute function public.notify_reminder_push();
insert into auth.users(id) values ('11111111-1111-4111-8111-111111111111'), ('22222222-2222-4222-8222-222222222222');

do $$
begin
  assert public.next_routine_run('2026-10-12', '19:00', 'Asia/Singapore', 7, '2026-10-12 10:59Z') = '2026-10-12 11:00Z';
  assert public.next_routine_run('2026-10-12', '19:00', 'Asia/Singapore', 7, '2026-10-12 11:00Z') = '2026-10-19 11:00Z';
  assert public.next_routine_run('2026-10-01', '19:00', 'Asia/Singapore', 3, '2026-10-12 11:00Z') = '2026-10-13 11:00Z';
  assert public.next_routine_run('2026-03-01', '19:00', 'America/New_York', 7, '2026-03-02 00:00Z') = '2026-03-08 23:00Z';
  assert public.next_routine_run('2026-10-25', '19:00', 'America/New_York', 7, '2026-10-26 00:00Z') = '2026-11-02 00:00Z';
  -- Nonexistent spring-forward times move forward; ambiguous fall-back times use standard time.
  assert public.next_routine_run('2026-03-08', '02:30', 'America/New_York', 1, '2026-03-08 00:00Z') = '2026-03-08 07:30Z';
  assert public.next_routine_run('2026-11-01', '01:30', 'America/New_York', 1, '2026-11-01 00:00Z') = '2026-11-01 06:30Z';
  begin
    perform public.next_routine_run('2026-10-12', '19:00', 'Invalid/Zone', 7, now());
    raise exception 'Invalid timezone accepted';
  exception when raise_exception then
    if sqlerrm <> 'Invalid routine schedule' then raise; end if;
  end;
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
-- Users cannot supply computed/internal fields.
select '11111111-1111-4111-8111-111111111111', 'Uniform', 7, '2026-10-12', '19:00', 'Asia/Singapore';
reset role;
update public.routine_reminders set next_run_at = now() - interval '21 days';
do $$
declare v_routine_id uuid; reminder_id uuid;
begin
  select id into v_routine_id from public.routine_reminders where text = 'Uniform';
  assert public.fire_due_routines() = 1;
  assert public.fire_due_routines() = 0, 'Repeated ticks must not fire twice';
  assert (select next_run_at > now() from public.routine_reminders where id = v_routine_id);
  select id into reminder_id from public.reminders where public.reminders.routine_id = v_routine_id;
  update public.reminders set is_done = true where id = reminder_id;
  update public.routine_reminders set next_run_at = now() - interval '1 minute' where id = v_routine_id;
  assert public.fire_due_routines() = 1;
  assert (select not is_done and completed_at is null from public.reminders where id = reminder_id);
  assert (select count(*) = 1 from public.reminders where public.reminders.routine_id = v_routine_id);
  assert exists (select 1 from routine_push_payloads where payload->>'type' = 'UPDATE'
    and payload->'record'->>'routine_fired_at' is distinct from payload->'old_record'->>'routine_fired_at'
    and payload->'record'->>'is_done' = 'false'), 'Reactivation webhook must carry old and new markers';
  update public.routine_reminders set enabled = false where id = v_routine_id;
  update public.routine_reminders set next_run_at = now() - interval '1 minute' where id = v_routine_id;
  assert public.fire_due_routines() = 0, 'Paused routines stay silent';
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
do $$
begin
  assert (select count(*) = 0 from public.routine_reminders), 'RLS leaked another user routine';
  begin
    perform public.fire_due_routines();
    raise exception 'Authenticated could run scheduler';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
    values ('11111111-1111-4111-8111-111111111111', 'Other user', 7, current_date, '19:00', 'UTC');
    raise exception 'Cross-user creation succeeded';
  exception when insufficient_privilege then null;
  end;
end $$;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
update public.routine_reminders set enabled = true;
do $$
begin
  assert (select next_run_at > now() from public.routine_reminders), 'Resume must skip missed occurrences';
  begin
    update public.routine_reminders set next_run_at = now();
    raise exception 'Client overwrote server schedule';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
-- Deleting a routine stops scheduling and preserves its existing board reminder.
delete from public.routine_reminders;
do $$ begin
  assert public.fire_due_routines() = 0;
  assert (select count(*) = 1 from public.reminders where routine_id is null);
end $$;
rollback;
