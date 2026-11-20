-- Run on a disposable database. The two sessions need committed fixtures.
create extension if not exists dblink with schema extensions;
select extensions.dblink_connect('scheduler', format('dbname=%L user=%L host=%L port=%L',
  current_database(), current_user, split_part(current_setting('unix_socket_directories'), ',', 1),
  current_setting('port')));
select extensions.dblink_exec('scheduler', 'set statement_timeout = ''15s''');

begin;
insert into auth.users(id) values
  ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b');
insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
  select id, 'Routine', 1, current_date, '09:00', 'UTC' from auth.users
  where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
update public.routine_reminders set next_run_at = '2000-01-01 09:00Z'
  where user_id = '00000000-0000-0000-0000-00000000000a';
update public.routine_reminders set next_run_at = now() - interval '2 minutes'
  where user_id = '00000000-0000-0000-0000-00000000000b';
insert into public.reminders(user_id, text, is_done, completed_at)
  select user_id, 'Expired', true, now() - interval '4 days' from public.routine_reminders
  where user_id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
commit;

begin;
-- A is due first. Keep its owner lock until B's firing is visible here.
select pg_advisory_xact_lock(hashtextextended('00000000-0000-0000-0000-00000000000a', 0));
select extensions.dblink_exec('scheduler', 'begin');
do $$ begin
  assert (select fired = 1 from extensions.dblink('scheduler', 'select public.fire_due_routines()') as result(fired integer)),
    'Scheduler must skip busy A and fire B';
end $$;

set local lock_timeout = '3s';
do $$ begin
  assert public.delete_old_completed_reminders() = 1, 'Cleanup must delete A and skip busy owner B';
  assert exists (select 1 from public.reminders where is_done and user_id = '00000000-0000-0000-0000-00000000000b');
end $$;
select extensions.dblink_exec('scheduler', 'commit');
do $$ begin
  assert exists (select 1 from public.reminders where routine_id is not null
    and user_id = '00000000-0000-0000-0000-00000000000b'), 'B must commit while A is locked';
  assert not exists (select 1 from public.reminders where routine_id is not null
    and user_id = '00000000-0000-0000-0000-00000000000a'), 'A must stay pending';
end $$;
commit;

do $$ begin
  assert public.fire_due_routines() = 1, 'The next tick must retry A';
  assert exists (select 1 from public.reminders where user_id = '00000000-0000-0000-0000-00000000000a'
    and routine_fired_at = '2000-01-01 09:00Z'), 'A must fire its original occurrence';
  assert public.fire_due_routines() = 0, 'Neither occurrence may fire twice';
  assert public.delete_old_completed_reminders() = 1, 'The next cleanup must remove the skipped row';
  assert not exists (select 1 from public.reminders where is_done
    and user_id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'));
end $$;
select extensions.dblink_disconnect('scheduler');
delete from auth.users where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
