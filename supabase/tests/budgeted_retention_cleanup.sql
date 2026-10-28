-- Disposable database only. No push requests or fixture data survive this test.
begin;
create or replace function public.request_reminder_push(payload jsonb) returns bigint
language sql as $$ select 1::bigint $$;
insert into auth.users(id) values
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222');
-- Simulate history accumulated across multiple write windows.
alter table public.reminders disable trigger aaa_enforce_write_budget;
insert into public.reminders(user_id, text, is_done, completed_at)
select owner_id, 'Expired ' || n, true, now() - interval '8 days'
from (values ('11111111-1111-4111-8111-111111111111'::uuid),
             ('22222222-2222-4222-8222-222222222222'::uuid)) owners(owner_id)
cross join lateral generate_series(1, case when owner_id = '11111111-1111-4111-8111-111111111111'::uuid then 601 else 602 end) n;
insert into public.reminders(user_id, text, is_done, completed_at) values
 ('11111111-1111-4111-8111-111111111111', 'Active', false, null),
 ('11111111-1111-4111-8111-111111111111', 'Recent', true, now());
alter table public.reminders enable trigger aaa_enforce_write_budget;
insert into public.device_tokens(user_id, token)
values ('22222222-2222-4222-8222-222222222222', repeat('a', 64));
insert into public.lock_screen_prefs(user_id, max_lines)
values ('22222222-2222-4222-8222-222222222222', 5);
insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
values ('22222222-2222-4222-8222-222222222222', 'Routine', 1, current_date, '19:00', 'UTC');
insert into public.agent_tokens(user_id, name, token_hash)
values ('22222222-2222-4222-8222-222222222222', 'Agent', repeat('b', 64));
insert into public.user_write_budgets(user_id, window_started_at, writes)
values ('11111111-1111-4111-8111-111111111111', statement_timestamp() + interval '1 hour', 599)
on conflict (user_id) do update set writes = 599, window_started_at = excluded.window_started_at;
update public.user_write_budgets set writes = 599, window_started_at = statement_timestamp() + interval '1 hour';

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
do $$ begin
  assert public.delete_old_completed_reminders() = 1, 'Partial budget must preserve successful deletes';
  assert public.delete_old_completed_reminders() = 0, 'Exhaustion must return without rolling back earlier progress';
  assert (select count(*) = 600 from public.reminders where is_done and completed_at < now() - interval '7 days');
  assert (select count(*) = 2 from public.reminders where text in ('Active', 'Recent'));
end $$;
reset role;
do $$ begin
  assert (select count(*) = 602 from public.reminders where user_id = '22222222-2222-4222-8222-222222222222'), 'Authenticated cleanup must retain other owners';
  assert (select writes = 600 from public.user_write_budgets where user_id = '11111111-1111-4111-8111-111111111111');
end $$;

-- Service cleanup skips the exhausted owner and spends the other owner's slot.
set local role service_role;
do $$ begin
  assert public.delete_old_completed_reminders() = 1, 'One exhausted owner must not stall global retention';
  assert public.delete_old_completed_reminders() = 0;
end $$;
reset role;
-- Simulate the next window without a timing-dependent sleep.
update public.user_write_budgets set window_started_at = statement_timestamp() - interval '2 minutes'
where user_id = '11111111-1111-4111-8111-111111111111';
set local role authenticated;
do $$ begin
  assert public.delete_old_completed_reminders() = 600, 'The remaining backlog must resume in the next window';
  assert (select count(*) = 2 from public.reminders);
end $$;
reset role;

-- 601 reminders plus other budgeted rows must cascade even at full capacity.
delete from auth.users where id = '22222222-2222-4222-8222-222222222222';
do $$ begin
  assert not exists (select 1 from public.reminders where user_id = '22222222-2222-4222-8222-222222222222');
  assert not exists (select 1 from public.device_tokens);
  assert not exists (select 1 from public.lock_screen_prefs);
  assert not exists (select 1 from public.routine_reminders);
  assert not exists (select 1 from public.agent_tokens);
  assert not exists (select 1 from public.user_write_budgets where user_id = '22222222-2222-4222-8222-222222222222');
  assert (select count(*) = 2 from public.reminders), 'Account cascades must retain the other owner';
end $$;
rollback;
