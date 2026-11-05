-- Run only on a disposable database, after the device-token quota migration.
begin;
insert into auth.users(id) values
  ('55555555-5555-4555-8555-555555555551'),
  ('55555555-5555-4555-8555-555555555552');
insert into public.device_tokens(token, user_id, updated_at, activity_push_token)
select lpad(n::text, 64, '0'), '55555555-5555-4555-8555-555555555551',
  '2020-01-01'::timestamptz + n * interval '1 day', repeat('a', 64)
from generate_series(1, 5) n;
insert into public.device_tokens(token, user_id, updated_at)
values (repeat('b', 64), '55555555-5555-4555-8555-555555555552', '2010-01-01');

set local role authenticated;
set local request.jwt.claim.sub = '55555555-5555-4555-8555-555555555551';
-- Match the native registration upsert: refresh the oldest device at capacity.
insert into public.device_tokens(token, user_id, environment)
values (lpad('1', 64, '0'), auth.uid(), 'development')
on conflict (token) do update set user_id = excluded.user_id, environment = excluded.environment;
do $$ begin
  assert (select count(*) = 5 from public.device_tokens), 'Refresh evicted a device';
  assert (select activity_push_token = repeat('a', 64) and environment = 'development'
    and updated_at > '2020-01-10' from public.device_tokens where token = lpad('1', 64, '0')),
    'Refresh must preserve device state and advance recency';
end $$;

-- The sixth registration succeeds and evicts token 2, now the oldest update.
insert into public.device_tokens(token, user_id) values (lpad('6', 64, '0'), auth.uid());
do $$ begin
  assert (select count(*) = 5 from public.device_tokens), 'Device quota exceeded';
  assert not exists (select 1 from public.device_tokens where token = lpad('2', 64, '0')),
    'Must evict the oldest-updated registration';
  assert exists (select 1 from public.device_tokens where token = lpad('6', 64, '0')),
    'New registration must survive eviction';
  begin
    insert into public.device_tokens(token, user_id)
    values (repeat('c', 64), '55555555-5555-4555-8555-555555555552');
    raise exception 'Registration bypassed owner RLS';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.device_tokens(token, user_id) values ('invalid', auth.uid());
    raise exception 'Invalid token accepted';
  exception when check_violation then null;
  end;
  assert (select count(*) = 5 from public.device_tokens), 'Failed insert retained its eviction';
end $$;

-- A bulk request must not bypass the row-level quota.
insert into public.device_tokens(token, user_id)
select lpad(n::text, 64, '0'), auth.uid() from generate_series(10, 29) n;
do $$ begin
  assert (select count(*) = 5 from public.device_tokens), 'Bulk insert bypassed quota';
end $$;
reset role;
do $$ begin
  assert (select count(*) = 1 from public.device_tokens
    where user_id = '55555555-5555-4555-8555-555555555552'), 'Another user lost a device';
  assert exists (select 1 from public.device_tokens where token = repeat('b', 64)),
    'Another user''s older device was evicted';
  assert not has_function_privilege('authenticated', 'public.enforce_device_token_quota()', 'execute');
  assert not has_function_privilege('anon', 'public.enforce_device_token_quota()', 'execute');
end $$;

-- Existing over-quota accounts are brought within the limit on registration.
alter table public.device_tokens disable trigger device_tokens_enforce_quota;
insert into public.device_tokens(token, user_id, updated_at)
select lpad(n::text, 64, 'a'), '55555555-5555-4555-8555-555555555552',
  '2020-01-01'::timestamptz + n * interval '1 day'
from generate_series(1, 7) n;
alter table public.device_tokens enable trigger device_tokens_enforce_quota;
set local role authenticated;
set local request.jwt.claim.sub = '55555555-5555-4555-8555-555555555552';
insert into public.device_tokens(token, user_id) values (repeat('c', 64), auth.uid());
do $$ begin
  assert (select count(*) = 5 from public.device_tokens), 'Legacy account remains over quota';
  assert (select count(*) = 4 from public.device_tokens
    where token in (lpad('4', 64, 'a'), lpad('5', 64, 'a'), lpad('6', 64, 'a'), lpad('7', 64, 'a'))),
    'Legacy eviction must retain the most recently updated registrations';
end $$;
reset role;
-- Privileged ownership changes must also reserve capacity for the recipient.
update public.device_tokens set user_id = '55555555-5555-4555-8555-555555555552'
where token = lpad('29', 64, '0');
do $$ begin
  assert (select count(*) = 5 from public.device_tokens
    where user_id = '55555555-5555-4555-8555-555555555552'), 'Ownership update bypassed quota';
  assert not exists (select 1 from public.device_tokens where token = lpad('4', 64, 'a')),
    'Ownership update did not evict the recipient''s oldest device';
end $$;
rollback;

-- Two real sessions compete for the fifth slot. The second must wait BEFORE
-- counting, then see the first committed registration and evict the oldest.
create extension if not exists dblink with schema extensions;
select extensions.dblink_connect('device_quota_race', format('dbname=%L user=%L host=%L port=%L',
  current_database(), current_user, split_part(current_setting('unix_socket_directories'), ',', 1),
  current_setting('port')));
create temporary table device_quota_peer as
select pid from extensions.dblink('device_quota_race', 'select pg_backend_pid()') as t(pid integer);
insert into auth.users(id) values ('55555555-5555-4555-8555-555555555553');
insert into public.device_tokens(token, user_id, updated_at)
select lpad(n::text, 64, 'd'), '55555555-5555-4555-8555-555555555553',
  '2020-01-01'::timestamptz + n * interval '1 day'
from generate_series(1, 4) n;
select extensions.dblink_exec('device_quota_race', 'set role authenticated');
select extensions.dblink_exec('device_quota_race',
  'set request.jwt.claim.sub = ''55555555-5555-4555-8555-555555555553''');
select extensions.dblink_exec('device_quota_race', 'set statement_timeout = ''10s''');
begin;
set local role authenticated;
set local request.jwt.claim.sub = '55555555-5555-4555-8555-555555555553';
insert into public.device_tokens(token, user_id) values (lpad('5', 64, 'd'), auth.uid());
reset role;
select extensions.dblink_send_query('device_quota_race',
  'insert into public.device_tokens(token, user_id) values (lpad(''6'', 64, ''d''), auth.uid()) returning token');
do $$ begin
  for attempt in 1..200 loop
    if exists (select 1 from pg_locks where pid = (select pid from device_quota_peer)
      and locktype = 'advisory' and not granted) then
      return;
    end if;
    perform pg_sleep(0.01);
  end loop;
  raise exception 'Concurrent registration did not wait for the per-user quota lock';
end $$;
commit;
select token from extensions.dblink_get_result('device_quota_race') as t(token text);
select token from extensions.dblink_get_result('device_quota_race') as t(token text);
do $$ begin
  assert (select count(*) = 5 from public.device_tokens
    where user_id = '55555555-5555-4555-8555-555555555553'), 'Concurrent registrations exceeded quota';
  assert not exists (select 1 from public.device_tokens where token = lpad('1', 64, 'd')),
    'Waiting registration did not evict the oldest committed device';
  assert (select count(*) = 2 from public.device_tokens
    where token in (lpad('5', 64, 'd'), lpad('6', 64, 'd'))), 'Concurrent new devices were lost';
end $$;
select extensions.dblink_disconnect('device_quota_race');
drop table device_quota_peer;
delete from auth.users where id = '55555555-5555-4555-8555-555555555553';
