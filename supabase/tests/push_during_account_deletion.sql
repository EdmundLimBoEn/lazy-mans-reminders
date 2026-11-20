-- Disposable local database only. The deletion runs on a second connection.
create extension if not exists dblink with schema extensions;
select extensions.dblink_connect('deleter', format('dbname=%L user=%L host=%L port=%L',
  current_database(), current_user, split_part(current_setting('unix_socket_directories'), ',', 1),
  current_setting('port')));
select extensions.dblink_exec('deleter', 'set statement_timeout = ''10s''');
create temporary table deleter_backend as
  select pid from extensions.dblink('deleter', 'select pg_backend_pid()') as backend(pid integer);

begin;
insert into auth.users(id) values ('5511accc-0000-4000-8000-000000000001');
insert into public.device_tokens(user_id, token) values
  ('5511accc-0000-4000-8000-000000000001', repeat('ac', 32));
insert into public.reminders(user_id, text) values
  ('5511accc-0000-4000-8000-000000000001', 'Complete during deletion');
do $$ begin
  assert exists (select from public.reminder_push_jobs where device_token = repeat('ac', 32)),
    'An unlocked account should receive a push job';
end $$;
commit;

begin;
-- Hold the reminder until the deletion owns the parent row and waits on its cascade.
select id from public.reminders where user_id = '5511accc-0000-4000-8000-000000000001'
  for no key update;
select extensions.dblink_send_query('deleter', $$
  delete from auth.users where id = '5511accc-0000-4000-8000-000000000001' returning id
$$);
do $$
declare deadline timestamptz := clock_timestamp() + interval '5 seconds';
begin
  while not exists (select from deleter_backend where pg_backend_pid() = any(pg_blocking_pids(pid))) loop
    assert clock_timestamp() < deadline, 'Account deletion never waited on the reminder';
    perform pg_sleep(0.01);
  end loop;
end $$;

set local role authenticated;
set local request.jwt.claim.sub = '5511accc-0000-4000-8000-000000000001';
do $$ begin
  update public.reminders set is_done = true where user_id = auth.uid();
  assert found, 'Reminder completion did not update a row';
end $$;
reset role;
do $$ begin
  assert not exists (select from public.reminder_push_jobs
    where device_token = repeat('ac', 32) and payload->>'type' = 'UPDATE'),
    'Completion queued a push for a deleting account';
end $$;
commit;

-- Propagate any asynchronous deletion error and check its committed effects.
select id from extensions.dblink_get_result('deleter') as deleted(id uuid);
select extensions.dblink_disconnect('deleter');
do $$ begin
  assert not exists (select from auth.users where id = '5511accc-0000-4000-8000-000000000001'),
    'Account deletion did not commit';
  assert not exists (select from public.reminder_push_jobs where user_id = '5511accc-0000-4000-8000-000000000001'),
    'Account deletion left a push job';
end $$;
