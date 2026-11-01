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
-- Known UUIDs model an attacker who already knows the victim's routine ID.
insert into public.routine_reminders(id, user_id, text, interval_days, start_date, local_time, timezone)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'Victim private text', 1, current_date, '19:00', 'UTC'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '22222222-2222-4222-8222-222222222222', 'Attacker routine', 1, current_date, '19:00', 'UTC');
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
do $$
declare own_reminder uuid;
begin
  begin
    insert into public.reminders(user_id, text, routine_id)
    values ('22222222-2222-4222-8222-222222222222', 'Stolen link', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    raise exception 'Cross-user routine insert succeeded';
  exception when foreign_key_violation then null;
  end;
  insert into public.reminders(user_id, text, routine_id)
  values ('22222222-2222-4222-8222-222222222222', 'Own link', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')
  returning id into own_reminder;
  begin
    update public.reminders set routine_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' where id = own_reminder;
    raise exception 'Cross-user routine update succeeded';
  exception when foreign_key_violation then null;
  end;
  begin
    update public.reminders set sort_order = '-2147483648'::integer where id = own_reminder;
    raise exception 'Integer minimum sort order accepted';
  exception when check_violation then null;
  end;
  update public.reminders set sort_order = -2147483647 where id = own_reminder;
end $$;
reset role;
update public.routine_reminders set next_run_at = now() - interval '1 minute';
do $$ begin
  assert public.fire_due_routines() = 2, 'Boundary sort order must not block either user';
  assert (select text = 'Attacker routine' and sort_order = -2147483647 from public.reminders
    where routine_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
  assert (select text = 'Victim private text' and user_id = '11111111-1111-4111-8111-111111111111' from public.reminders
    where routine_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
end $$;

-- Simulate a corrupt schedule: failure after the reminder write must roll back
-- that write, preserve earlier successes, and allow later routines to run.
insert into public.routine_reminders(id, user_id, text, interval_days, start_date, local_time, timezone)
values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '11111111-1111-4111-8111-111111111111', 'Bad schedule', 1, current_date, '19:00', 'UTC');
alter table public.routine_reminders disable trigger prepare_routine_schedule;
update public.routine_reminders set timezone = 'Invalid/Zone', next_run_at = now() - interval '2 minutes'
  where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
alter table public.routine_reminders enable trigger prepare_routine_schedule;
update public.routine_reminders set next_run_at = now() - interval '3 minutes'
  where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
update public.routine_reminders set next_run_at = now() - interval '1 minute'
  where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
update public.reminders set is_done = true where routine_id is not null;
do $$ begin
  assert public.fire_due_routines() = 2, 'One bad routine must not abort other routines';
  assert (select count(*) = 2 from public.reminders where routine_id is not null and not is_done);
  assert (select count(*) = 2 from public.routine_reminders where next_run_at > now());
  assert (select next_run_at <= now() from public.routine_reminders where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc');
  assert not exists (select 1 from public.reminders where routine_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
    'Failed routine must roll back its reminder write';
end $$;
delete from public.routine_reminders;
do $$ begin
  assert not exists (select 1 from public.reminders where routine_id is not null);
  assert (select count(*) = 1 from public.reminders where user_id = '22222222-2222-4222-8222-222222222222'),
    'Composite FK deletion must preserve the reminder and its owner';
end $$;
rollback;

-- Text corrections must retain pending firings even when a full board delays them.
begin;
create temporary table routine_push_payloads(payload jsonb);
create or replace function public.request_reminder_push(payload jsonb) returns bigint
language plpgsql as $$ begin
  insert into routine_push_payloads values (payload);
  return 1;
end $$;
insert into auth.users(id) values ('11111111-1111-4111-8111-111111111111');
insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
values ('11111111-1111-4111-8111-111111111111', 'Original', 1, current_date, '09:00', 'UTC');
insert into public.reminders(user_id, text)
select '11111111-1111-4111-8111-111111111111', 'Board item ' || n from generate_series(1, 16) n;
update public.routine_reminders set next_run_at = now() - interval '1 minute';
do $$ begin
  assert public.fire_due_routines() = 0, 'Full board must leave the routine pending';
end $$;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
update public.routine_reminders set text = '  Corrected  ';
do $$ begin
  assert (select text = 'Corrected' and next_run_at = now() - interval '1 minute'
    from public.routine_reminders), 'Text-only edit must trim text and preserve overdue firing';
end $$;
-- The web editor submits all schedule fields, even when only text changed.
update public.routine_reminders set text = 'Corrected again', start_date = start_date,
  local_time = local_time, timezone = timezone, interval_days = interval_days, enabled = enabled;
do $$ begin
  assert (select next_run_at = now() - interval '1 minute' from public.routine_reminders),
    'Resubmitting unchanged schedule values must preserve overdue firing';
end $$;
reset role;
delete from public.reminders where text = 'Board item 1';
do $$ begin
  assert public.fire_due_routines() = 1, 'Edited pending routine must fire when space opens';
  assert exists (select 1 from public.reminders where routine_id is not null
    and text = 'Corrected again' and routine_fired_at = now() - interval '1 minute'),
    'Firing must use corrected text and the original occurrence timestamp';
  assert public.fire_due_routines() = 0, 'Scheduler must still advance after firing';
end $$;
-- Use a distinct future marker so unconditional recalculation cannot pass by coincidence.
update public.routine_reminders set next_run_at = now() + interval '12 hours';
set local role authenticated;
update public.routine_reminders set text = 'Future correction';
do $$ begin
  assert (select next_run_at = now() + interval '12 hours' from public.routine_reminders),
    'Text-only edit must preserve a future firing too';
end $$;
reset role;
-- Each actual schedule/state change must continue to calculate a new future run.
do $$
declare assignment text;
begin
  foreach assignment in array array[
    'start_date = start_date + 1', 'local_time = time ''10:00''',
    'timezone = ''Asia/Singapore''', 'interval_days = 2', 'enabled = false', 'enabled = true'
  ] loop
    update public.routine_reminders set next_run_at = now() - interval '1 minute';
    execute 'set local role authenticated';
    execute 'update public.routine_reminders set ' || assignment;
    assert (select next_run_at = public.next_routine_run(start_date, local_time, timezone, interval_days, now())
      and next_run_at > now() from public.routine_reminders),
      'Changed schedule/state must recalculate: ' || assignment;
    execute 'reset role';
  end loop;
end $$;
rollback;
