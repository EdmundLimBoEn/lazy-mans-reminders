-- Disposable database only; fixtures and the network-free push stub roll back.
begin;
create temporary table budget_pushes(payload jsonb);
create or replace function public.request_reminder_push(payload jsonb) returns bigint
language plpgsql as $$ begin
  insert into budget_pushes values (payload);
  return 1;
end $$;
drop trigger if exists send_reminder_push on public.reminders;
create trigger send_reminder_push after insert or update or delete on public.reminders
  for each row execute function public.notify_reminder_push();
insert into auth.users(id) values
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222');
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
insert into public.reminders(user_id, text) values (auth.uid(), 'Budget fixture');
insert into public.lock_screen_prefs(user_id, max_lines) values (auth.uid(), 5);
insert into public.device_tokens(user_id, token) values (auth.uid(), repeat('a', 64));
insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
values (auth.uid(), 'Routine fixture', 1, current_date, '19:00', 'UTC');
-- Upserts charge once, despite running both INSERT and UPDATE BEFORE triggers.
insert into public.lock_screen_prefs(user_id, max_lines) values (auth.uid(), 6)
on conflict (user_id) do update set max_lines = excluded.max_lines;
reset role;
do $$ begin
  assert (select writes = 5 from public.user_write_budgets), 'All tables share one budget; upsert counts once';
end $$;
-- Hold a fixed future window to avoid a wall-clock minute rollover in this test.
update public.user_write_budgets set window_started_at = statement_timestamp() + interval '1 hour';
set local role authenticated;
do $$ begin
  for i in 1..595 loop
    update public.reminders set text = 'Edit ' || i where user_id = auth.uid();
  end loop;
  begin
    update public.reminders set text = 'Over budget' where user_id = auth.uid();
    raise exception 'Repeated direct updates bypassed the budget';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
  begin
    delete from public.reminders where user_id = auth.uid();
    raise exception 'Delete bypassed the budget';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
  begin
    update public.lock_screen_prefs set max_lines = 7 where user_id = auth.uid();
    raise exception 'Preference update bypassed shared budget';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
  begin
    update public.device_tokens set environment = 'development' where user_id = auth.uid();
    raise exception 'Device update bypassed shared budget';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
  begin
    update public.routine_reminders set enabled = false where user_id = auth.uid();
    raise exception 'Routine update bypassed shared budget';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
  begin
    delete from public.user_write_budgets;
    raise exception 'Client reset its budget';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
do $$ begin
  assert (select writes = 600 from public.user_write_budgets);
  assert (select text = 'Edit 595' from public.reminders);
  assert (select count(*) = 596 from budget_pushes), 'Rejected writes must not enqueue notifications';
end $$;
-- Service-role/RPC writes use the same row owner budget without an auth.uid().
set local role service_role;
set local request.jwt.claim.sub = '';
do $$ begin
  begin
    update public.reminders set text = 'Service bypass';
    raise exception 'Service writer bypassed the budget';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
  begin
    insert into public.agent_tokens(user_id, name, token_hash)
    values ('11111111-1111-4111-8111-111111111111', 'Budget fixture', 'test-only-hash');
    raise exception 'Agent token write bypassed shared budget';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
end $$;
reset role;
-- Another account remains able to write; switching identity cannot reset owner 1.
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
insert into public.reminders(user_id, text) values (auth.uid(), 'Other user');
reset role;
-- Expiry replenishes capacity without adding counter rows.
update public.user_write_budgets set window_started_at = statement_timestamp() - interval '2 minutes'
where user_id = '11111111-1111-4111-8111-111111111111';
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
update public.reminders set text = 'New window' where user_id = auth.uid();
reset role;
do $$ begin
  assert (select writes = 1 from public.user_write_budgets where user_id = '11111111-1111-4111-8111-111111111111');
end $$;
-- A multi-row statement with only one slot left must roll back all rows/charges.
update public.user_write_budgets set writes = 599, window_started_at = statement_timestamp() + interval '1 hour'
where user_id = '11111111-1111-4111-8111-111111111111';
truncate budget_pushes;
set local role authenticated;
do $$ begin
  begin
    insert into public.reminders(user_id, text, is_done)
    select auth.uid(), 'Bulk ' || n, true from generate_series(1, 2) n;
    raise exception 'Bulk insert bypassed budget';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
  assert not exists (select 1 from public.reminders where text like 'Bulk %');
end $$;
reset role;
do $$ begin
  assert (select writes = 599 from public.user_write_budgets where user_id = '11111111-1111-4111-8111-111111111111');
  assert not exists (select 1 from budget_pushes), 'Bulk failure must roll back notification queue';
end $$;
update public.user_write_budgets set writes = 600;
delete from auth.users where id = '11111111-1111-4111-8111-111111111111';
do $$ begin
  assert not exists (select 1 from public.user_write_budgets where user_id = '11111111-1111-4111-8111-111111111111');
  assert not exists (select 1 from public.reminders where user_id = '11111111-1111-4111-8111-111111111111');
end $$;
rollback;
