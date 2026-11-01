-- Run after migrations against a disposable database. All fixtures roll back.
begin;
-- Capture the real trigger's enqueue calls without making network requests.
create temporary table quota_push_payloads(payload jsonb);
create or replace function public.request_reminder_push(payload jsonb) returns bigint
language plpgsql as $$ begin
  insert into quota_push_payloads values (payload);
  return 1;
end $$;
-- The focused CI migration list omits the original push infrastructure.
drop trigger if exists send_reminder_push on public.reminders;
create trigger send_reminder_push after insert or update or delete on public.reminders
  for each row execute function public.notify_reminder_push();
insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
-- Completed reminders consume no slots, even when there are more than 16 of them.
insert into public.reminders(user_id, text, is_done)
select auth.uid(), 'Completed ' || n, true from generate_series(1, 20) n;
insert into public.reminders(user_id, text)
select auth.uid(), 'Active ' || n from generate_series(1, 16) n;
do $$ declare quota_detail text; begin
  assert (select count(*) = 16 from public.reminders where not is_done);
  begin
    insert into public.reminders(user_id, text) values (auth.uid(), 'Overflow');
    raise exception '17th active reminder accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'You can have at most 16 active reminders. Complete or delete a reminder before adding another.' then raise; end if;
  end;
  begin
    update public.reminders set is_done = false where text = 'Completed 1';
    raise exception 'Reactivation bypassed the quota';
  exception when sqlstate 'P0001' then
    get stacked diagnostics quota_detail = PG_EXCEPTION_DETAIL;
    assert quota_detail = '16 LMR_CAPACITY_REACHED', 'Reopen quota must expose its machine-readable capacity';
    if sqlerrm <> 'You can have at most 16 active reminders. Complete or delete a reminder before adding another.' then raise; end if;
  end;
end $$;
-- Completed inserts and ordinary edits remain possible on a full board.
insert into public.reminders(user_id, text, is_done) values (auth.uid(), 'Also completed', true);
insert into public.reminders(id, user_id, text)
select id, user_id, 'Upserted' from public.reminders where text = 'Active 16'
on conflict (id) do update set text = excluded.text, is_done = excluded.is_done;
update public.reminders set text = 'Edited' where text = 'Active 1';
update public.reminders set is_done = true where text = 'Edited';
do $$ begin
  begin
    insert into public.reminders(user_id, text)
    select auth.uid(), 'Bulk ' || n from generate_series(1, 2) n;
    raise exception 'Bulk insert exceeded the quota';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'You can have at most 16 active reminders. Complete or delete a reminder before adding another.' then raise; end if;
  end;
  assert (select count(*) = 15 from public.reminders where not is_done), 'Failed bulk insert must roll back every row';
end $$;
insert into public.reminders(user_id, text) values (auth.uid(), 'Replacement');
delete from public.reminders where text = 'Replacement';
update public.reminders set is_done = false where text = 'Completed 1';

-- Disabled routines still count toward the per-user storage quota.
insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone, enabled)
select auth.uid(), 'Routine ' || n, 1, current_date, '19:00', 'UTC', n % 2 = 0
from generate_series(1, 50) n;
do $$ begin
  assert (select count(*) = 50 from public.routine_reminders);
  begin
    insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
    values (auth.uid(), 'Overflow', 1, current_date, '19:00', 'UTC');
    raise exception '51st routine accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'You can have at most 50 routines. Delete a routine before adding another.' then raise; end if;
  end;
end $$;
delete from public.routine_reminders where text = 'Routine 1';
insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
values (auth.uid(), 'Replacement routine', 1, current_date, '19:00', 'UTC');

-- A different user has independent capacity despite the first user's full board.
set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
insert into public.reminders(user_id, text) values (auth.uid(), 'Other board');
insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
values (auth.uid(), 'Other routine', 1, current_date, '19:00', 'UTC');
reset role;

-- Scheduler ON CONFLICT refreshes must still work at capacity.
update public.reminders set routine_id = (select id from public.routine_reminders where text = 'Routine 2')
where text = 'Active 2';
update public.routine_reminders set next_run_at = now() - interval '1 minute' where text = 'Routine 2';
do $$ begin
  assert public.fire_due_routines() = 1, 'A full board must allow refreshing its existing active routine';
  assert (select count(*) = 16 from public.reminders
    where user_id = '11111111-1111-4111-8111-111111111111' and not is_done);
end $$;
-- A completed routine needs a slot to reactivate, and remains due until one opens.
update public.reminders set is_done = true where text = 'Routine 2';
insert into public.reminders(user_id, text)
values ('11111111-1111-4111-8111-111111111111', 'Block routine');
update public.routine_reminders set next_run_at = now() - interval '1 minute' where text = 'Routine 2';
do $$ begin
  assert public.fire_due_routines() = 0, 'Routine reactivation must respect the quota';
  assert (select next_run_at < now() from public.routine_reminders where text = 'Routine 2');
  assert (select is_done from public.reminders where text = 'Routine 2');
end $$;
delete from public.reminders where text = 'Block routine';
do $$ begin
  assert public.fire_due_routines() = 1, 'Routine must retry when capacity becomes available';
end $$;

-- Give updated_at an old value so the no-op really changes that timestamp.
insert into public.reminders(user_id, text, updated_at)
values ('22222222-2222-4222-8222-222222222222', 'Push fixture', now() - interval '1 day');
do $$ begin
  assert exists (select 1 from quota_push_payloads
    where payload->>'type' = 'INSERT' and payload->'record'->>'text' = 'Push fixture');
end $$;
truncate quota_push_payloads;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
update public.reminders set text = text, sort_order = sort_order, is_done = is_done where text = 'Push fixture';
reset role;
do $$ begin
  assert (select updated_at = now() from public.reminders where text = 'Push fixture');
  assert (select count(*) = 0 from quota_push_payloads), 'No-op updates must not enqueue pushes';
end $$;

set local role authenticated;
update public.reminders set text = 'Changed' where text = 'Push fixture';
update public.reminders set sort_order = 5 where text = 'Changed';
update public.reminders set is_done = true where text = 'Changed';
reset role;
do $$ begin
  assert (select count(*) = 3 from quota_push_payloads), 'Text, ordering and completion changes must enqueue';
  assert exists (select 1 from quota_push_payloads where payload->>'type' = 'UPDATE'
    and payload->'record'->>'text' = 'Changed' and payload->'old_record'->>'text' = 'Push fixture');
end $$;
truncate quota_push_payloads;
-- NULL-safe comparison must preserve routine notifications and detachment.
update public.reminders set routine_id = (select id from public.routine_reminders where text = 'Other routine'),
  routine_fired_at = now() where text = 'Changed';
update public.reminders set routine_fired_at = now() + interval '1 minute' where text = 'Changed';
update public.reminders set routine_id = null where text = 'Changed';
delete from public.reminders where text = 'Changed';
do $$ begin
  assert (select count(*) = 4 from quota_push_payloads), 'Routine markers, detachment and deletes must enqueue';
  assert exists (select 1 from quota_push_payloads where payload->>'type' = 'DELETE'
    and payload->'record'->>'text' = 'Changed');
end $$;
rollback;
