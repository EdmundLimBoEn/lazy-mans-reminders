-- Disposable database only. Committed fixtures are shared by two real sessions.
create extension if not exists dblink with schema extensions;
select extensions.dblink_connect('activity_ack', format('dbname=%L user=%L host=%L port=%L',
  current_database(), current_user, split_part(current_setting('unix_socket_directories'), ',', 1),
  current_setting('port')));
select extensions.dblink_exec('activity_ack', 'set statement_timeout = ''10s''');
create temporary table activity_ack_backend as
  select pid from extensions.dblink('activity_ack', 'select pg_backend_pid()') as backend(pid integer);

begin;
insert into auth.users(id) values ('77777777-7777-4777-8777-777777777777');
insert into public.device_tokens(token, user_id)
  values (repeat('7', 64), '77777777-7777-4777-8777-777777777777');
insert into public.reminders(user_id, text)
  values ('77777777-7777-4777-8777-777777777777', 'Completion lock regression');
select public.claim_live_activity_start(repeat('7', 64),
  '77777777-7777-4777-8777-777777777777', '77777777-7777-4777-8777-777777777771', null, null);
commit;

-- Hold the budget at the point before a reminder notification queues jobs.
-- Do not queue a job yet: its FK lock would mask the old completion lock.
begin;
select user_id from public.user_write_budgets
  where user_id = '77777777-7777-4777-8777-777777777777' for update;
select extensions.dblink_send_query('activity_ack', $$
  select public.complete_live_activity_start(repeat('7', 64),
    '77777777-7777-4777-8777-777777777777', null, '2026-11-02 00:00:00+00', false,
    '77777777-7777-4777-8777-777777777771')
$$);
do $$
declare deadline timestamptz := clock_timestamp() + interval '5 seconds';
begin
  -- Wait for completion to hold the device lock and block on our budget row.
  loop
    exit when exists (select 1 from activity_ack_backend
      where pg_backend_pid() = any(pg_blocking_pids(pid)));
    assert clock_timestamp() < deadline, 'Acknowledgement never waited on the write budget';
    perform pg_sleep(0.01);
  end loop;
end $$;

-- Exercise the notification's actual job insertion/FK check. With FOR UPDATE
-- in completion this times out (or deadlocks), rather than committing both writes.
set local lock_timeout = '500ms';
update public.reminders set is_done = true
  where user_id = '77777777-7777-4777-8777-777777777777';
-- CI's minimal migration set omits the notification trigger, so also call its
-- enqueue function directly. Full database installations exercise both paths.
select public.request_reminder_push(jsonb_build_object('type', 'UPDATE',
  'record', jsonb_build_object('user_id', '77777777-7777-4777-8777-777777777777')));
commit;
select * from extensions.dblink_get_result('activity_ack') as result(completed text);
select * from extensions.dblink_get_result('activity_ack') as result(completed text);
do $$ begin
  assert (select activity_started_at = '2026-11-02 00:00:00+00'::timestamptz
    from public.device_tokens where token = repeat('7', 64)), 'Acknowledgement did not commit';
  assert not exists (select 1 from public.live_activity_start_leases
    where device_token = repeat('7', 64)), 'Acknowledgement did not consume its lease';
  assert exists (select 1 from public.reminder_push_jobs
    where device_token = repeat('7', 64) and payload->>'type' = 'UPDATE'),
    'Reminder push job did not commit';
  assert (select is_done from public.reminders
    where user_id = '77777777-7777-4777-8777-777777777777'), 'Reminder completion did not commit';
end $$;

-- The weaker lock must still exclude other device writers, even for a stale
-- acknowledgement that returns before record_live_activity_start updates it.
select extensions.dblink_exec('activity_ack', 'begin');
select * from extensions.dblink('activity_ack', $$
  select public.complete_live_activity_start(repeat('7', 64),
    '77777777-7777-4777-8777-777777777777', null, now(), false,
    '77777777-7777-4777-8777-777777777771')
$$) as result(completed text);
do $$ begin
  begin
    perform 1 from public.device_tokens where token = repeat('7', 64) for no key update nowait;
    raise exception 'Acknowledgement failed to serialize device writers';
  exception when lock_not_available then null;
  end;
end $$;
select extensions.dblink_exec('activity_ack', 'rollback');
select extensions.dblink_disconnect('activity_ack');
drop table activity_ack_backend;
begin;
alter table public.reminders disable trigger user;
delete from auth.users where id = '77777777-7777-4777-8777-777777777777';
alter table public.reminders enable trigger user;
commit;
