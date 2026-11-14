-- Run only after migrations in a disposable local database. Everything rolls back.
begin;
do $$ begin
  assert exists (select 1 from information_schema.columns where table_schema = 'public'
    and table_name = 'reminders' and column_name = 'snoozed_until'
    and data_type = 'timestamp with time zone' and is_nullable = 'YES');
end $$;
create temporary table snooze_push_payloads(payload jsonb);
create or replace function public.request_reminder_push(payload jsonb) returns bigint
language plpgsql as $$ begin
  insert into snooze_push_payloads values (payload);
  return 1;
end $$;
drop trigger if exists send_reminder_push on public.reminders;
create trigger send_reminder_push after insert or update or delete on public.reminders
  for each row execute function public.notify_reminder_push();
insert into auth.users(id) values ('33333333-3333-4333-8333-333333333333');
set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-4333-8333-333333333333';
insert into public.reminders(user_id, text)
select auth.uid(), 'Slot ' || n from generate_series(1, 16) n;
update public.reminders set snoozed_until = now() + interval '3 hours' where text = 'Slot 1';
insert into public.reminders(user_id, text) values (auth.uid(), 'Freed slot');
-- A text-only upsert of the hidden row consumes no visible slot at capacity.
insert into public.reminders(id, user_id, text)
select id, user_id, text from public.reminders where text = 'Slot 1'
on conflict (id) do update set text = excluded.text;
do $$ begin
  assert (select count(*) = 16 from public.reminders where not is_done
    and (snoozed_until is null or snoozed_until <= now()));
  begin
    insert into public.reminders(user_id, text) values (auth.uid(), 'Overflow');
    raise exception 'Quota accepted overflow';
  exception when sqlstate 'P0001' then
    if sqlerrm not like 'You can have at most 16%' then raise; end if;
  end;
  begin
    update public.reminders set snoozed_until = null where text = 'Slot 1';
    raise exception 'Early unsnooze bypassed quota';
  exception when sqlstate 'P0001' then
    if sqlerrm not like 'You can have at most 16%' then raise; end if;
  end;
  begin
    update public.reminders set snoozed_until = now() + interval '49 hours' where text = 'Slot 2';
    raise exception 'Accepted an excessive snooze';
  exception when raise_exception then
    if sqlerrm <> 'Snooze must be within 48 hours.' then raise; end if;
  end;
end $$;
-- Reordering accepts exactly the visible board, not the hidden seventeenth row.
select count(*) from public.reorder_reminders(array(
  select id from public.reminders where not is_done and snoozed_until is null order by id));
reset role;
do $$ begin
  assert exists (select 1 from snooze_push_payloads where payload->>'type' = 'UPDATE'
    and payload->'record'->>'snoozed_until' is not null), 'Snooze-only update must notify';
  assert not has_function_privilege('anon', 'public.clear_expired_snoozes()', 'execute');
  assert not has_function_privilege('authenticated', 'public.clear_expired_snoozes()', 'execute');
end $$;
-- Simulate elapsed time without sleeping: bypass quota only for the fixture timestamp.
alter table public.reminders disable trigger reminders_enforce_quota;
update public.reminders set snoozed_until = now() where text = 'Slot 1';
alter table public.reminders enable trigger reminders_enforce_quota;
truncate snooze_push_payloads;
do $$ begin
  assert public.clear_expired_snoozes() = 1;
  assert public.clear_expired_snoozes() = 0, 'Expiry must be idempotent';
  assert (select count(*) = 17 from public.reminders where user_id = '33333333-3333-4333-8333-333333333333'
    and not is_done and snoozed_until is null), 'Expired row returns even over quota';
  assert (select count(*) = 1 from snooze_push_payloads where payload->>'type' = 'UPDATE'
    and payload->'record'->>'snoozed_until' is null
    and payload->'old_record'->>'snoozed_until' is not null), 'Expiry must fire the push trigger';
  begin
    insert into public.reminders(user_id, text) values ('33333333-3333-4333-8333-333333333333', 'Still full');
    raise exception 'Overfull board accepted an add';
  exception when sqlstate 'P0001' then
    if sqlerrm not like 'You can have at most 16%' then raise; end if;
  end;
end $$;
update public.reminders set snoozed_until = now() + interval '1 hour' where text = 'Slot 1';
update public.reminders set is_done = true where text = 'Slot 1';
do $$ begin
  assert (select snoozed_until is null from public.reminders where text = 'Slot 1'), 'Completion must clear snooze';
end $$;
-- Agent RPC capacity also excludes future snoozes (default phone limit is six).
update public.reminders set snoozed_until = now() + interval '1 hour' where text like 'Slot %' and not is_done;
select * from public.add_agent_reminder('33333333-3333-4333-8333-333333333333', 'Agent with room');
do $$ begin
  assert (select count(*) = 2 from public.reminders where user_id = '33333333-3333-4333-8333-333333333333'
    and not is_done and snoozed_until is null);
end $$;
rollback;
