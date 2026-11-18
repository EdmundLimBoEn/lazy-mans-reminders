-- Run on a disposable database. The two sessions need committed fixtures.
create extension if not exists dblink with schema extensions;
select extensions.dblink_connect('scheduler', format('dbname=%L user=%L host=%L port=%L',
  current_database(), current_user, split_part(current_setting('unix_socket_directories'), ',', 1),
  current_setting('port')));
select extensions.dblink_exec('scheduler', 'set statement_timeout = ''15s''');
create temporary table scheduler_backend as
  select pid from extensions.dblink('scheduler', 'select pg_backend_pid()') as backend(pid integer);

begin;
insert into auth.users(id) values
  ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b');
insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone)
  select id, 'Routine', 1, current_date, '09:00', 'UTC' from auth.users
  where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
update public.routine_reminders set next_run_at = now() - interval '1 minute'
  where user_id = '00000000-0000-0000-0000-00000000000a';
update public.routine_reminders set next_run_at = now() - interval '2 minutes'
  where user_id = '00000000-0000-0000-0000-00000000000b';
insert into public.reminders(user_id, text, is_done, completed_at)
  select user_id, 'Expired', true, now() - interval '4 days' from public.routine_reminders
  where user_id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
commit;

begin;
-- Let the scheduler fire B first, then hold it at A until cleanup commits.
select pg_advisory_xact_lock(hashtextextended('00000000-0000-0000-0000-00000000000a', 0));
select extensions.dblink_send_query('scheduler', 'select public.fire_due_routines()');
do $$
declare deadline timestamptz := clock_timestamp() + interval '5 seconds';
begin
  loop
    exit when exists (select 1 from scheduler_backend where pg_backend_pid() = any(pg_blocking_pids(pid)));
    assert clock_timestamp() < deadline, 'Scheduler did not reach owner A';
    perform pg_sleep(0.01);
  end loop;
end $$;

set local lock_timeout = '3s';
do $$ begin
  assert public.delete_old_completed_reminders() = 1, 'Cleanup must delete A and skip busy owner B';
  assert exists (select 1 from public.reminders where is_done and user_id = '00000000-0000-0000-0000-00000000000b');
end $$;
commit;

do $$ begin
  assert (select fired = 2 from extensions.dblink_get_result('scheduler') as result(fired integer)),
    'Both routines must fire in the same scheduler run';
  assert public.delete_old_completed_reminders() = 1, 'The next cleanup must remove the skipped row';
  assert not exists (select 1 from public.reminders where is_done
    and user_id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'));
end $$;
select extensions.dblink_disconnect('scheduler');
drop table scheduler_backend;
delete from auth.users where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
