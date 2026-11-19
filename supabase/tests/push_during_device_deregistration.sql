-- Disposable local database only. Both connections need to see the fixtures.
create extension if not exists dblink with schema extensions;
select extensions.dblink_connect('writer', format('dbname=%L user=%L host=%L port=%L',
  current_database(), current_user, split_part(current_setting('unix_socket_directories'), ',', 1),
  current_setting('port')));
select extensions.dblink_exec('writer', 'set statement_timeout = ''10s''');
create temporary table writer_backend as
  select pid from extensions.dblink('writer', 'select pg_backend_pid()') as backend(pid integer);
select extensions.dblink_exec('writer', 'set role authenticated');
select extensions.dblink_exec('writer', $$set request.jwt.claim.sub = 'bb13ef11-8cf7-46e1-a531-000000000001'$$);

begin;
insert into auth.users(id) values ('bb13ef11-8cf7-46e1-a531-000000000001');
insert into public.device_tokens(user_id, token) values
  ('bb13ef11-8cf7-46e1-a531-000000000001', repeat('d1', 32)),
  ('bb13ef11-8cf7-46e1-a531-000000000001', repeat('d2', 32));
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = 'bb13ef11-8cf7-46e1-a531-000000000001';
delete from public.device_tokens where user_id = auth.uid() and token = repeat('d1', 32);
reset role;
select extensions.dblink_send_query('writer', $$
  insert into public.reminders(user_id, text) values (auth.uid(), 'During sign-out') returning id
$$);
do $$
declare deadline timestamptz := clock_timestamp() + interval '5 seconds';
begin
  while not exists (select from writer_backend where pg_backend_pid() = any(pg_blocking_pids(pid))) loop
    assert clock_timestamp() < deadline, 'Reminder insert never waited for device deletion';
    perform pg_sleep(0.01);
  end loop;
end $$;
commit;

-- Propagate any writer error, then check the committed reminder and its jobs.
create temporary table inserted_reminder as
  select id from extensions.dblink_get_result('writer') as result(id uuid);
select extensions.dblink_disconnect('writer');
do $$ begin
  assert exists (select from public.reminders join inserted_reminder using (id)),
    'Reminder insert did not commit';
  assert (select count(*) = 1 and bool_and(device_token = repeat('d2', 32))
          from public.reminder_push_jobs where user_id = 'bb13ef11-8cf7-46e1-a531-000000000001'),
    'Only the still-registered device should have a push job';
end $$;

delete from auth.users where id = 'bb13ef11-8cf7-46e1-a531-000000000001';
