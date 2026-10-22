-- Run on a disposable database after the listed migrations.
begin;
insert into auth.users(id) values ('33333333-3333-4333-8333-333333333333');
do $$
declare violated_constraint text;
begin
  assert (select convalidated from pg_constraint
    where conrelid = 'public.reminders'::regclass and conname = 'reminders_text_raw_length'),
    'Clean databases should validate the raw text constraint';
  insert into public.reminders(user_id, text) values
    ('33333333-3333-4333-8333-333333333333', repeat(' ', 500) || repeat('é', 500));
  begin
    insert into public.reminders(user_id, text) values
      ('33333333-3333-4333-8333-333333333333', repeat(' ', 1000) || 'x');
    raise exception 'Oversized padded insert accepted';
  exception when check_violation then
    get stacked diagnostics violated_constraint = constraint_name;
    assert violated_constraint = 'reminders_text_raw_length';
  end;
  begin
    update public.reminders set text = 'x' || repeat(' ', 1000)
    where user_id = '33333333-3333-4333-8333-333333333333';
    raise exception 'Oversized padded update accepted';
  exception when check_violation then
    get stacked diagnostics violated_constraint = constraint_name;
    assert violated_constraint = 'reminders_text_raw_length';
  end;
end $$;

-- Reapply the actual migration with a legacy oversized row, preserving function ACLs.
create temporary table mint_acl as select proacl from pg_proc
  where oid = 'public.mint_agent_token(text)'::regprocedure;
alter table public.reminders drop constraint reminders_text_raw_length;
insert into public.reminders(user_id, text) values
  ('33333333-3333-4333-8333-333333333333', repeat(' ', 10000) || 'legacy');
\ir ../migrations/202610220002_reminder_text_and_token_lock.sql
do $$
begin
  assert (select not convalidated from pg_constraint
    where conrelid = 'public.reminders'::regclass and conname = 'reminders_text_raw_length');
  assert exists (select 1 from public.reminders where char_length(text) > 1000),
    'Migration must preserve legacy rows';
  begin
    insert into public.reminders(user_id, text) values
      ('33333333-3333-4333-8333-333333333333', 'x' || repeat(' ', 1000));
    raise exception 'NOT VALID constraint allowed a new oversized row';
  exception when check_violation then null;
  end;
  assert (select p.proacl is not distinct from a.proacl from pg_proc p cross join mint_acl a
    where p.oid = 'public.mint_agent_token(text)'::regprocedure), 'Function grants changed';
  assert not has_function_privilege('anon', 'public.mint_agent_token(text)', 'execute');
  assert has_function_privilege('authenticated', 'public.mint_agent_token(text)', 'execute');
  assert has_function_privilege('service_role', 'public.mint_agent_token(text)', 'execute');
  assert (select prosecdef and proconfig = array['search_path=""'] from pg_proc
    where oid = 'public.mint_agent_token(text)'::regprocedure);
end $$;
rollback;

-- Two real sessions: the second mint must wait while the twentieth token is
-- uncommitted. Without the lock it sees 19, inserts another token, and fails here.
-- Fixtures must be committed to be visible to dblink; explicitly removed below.
create extension if not exists dblink with schema extensions;
select extensions.dblink_connect('token_race', format('dbname=%L user=%L host=%L port=%L',
  current_database(), current_user, split_part(current_setting('unix_socket_directories'), ',', 1),
  current_setting('port')));
insert into auth.users(id) values ('44444444-4444-4444-8444-444444444444');
insert into public.agent_tokens(user_id, name, token_hash)
select '44444444-4444-4444-8444-444444444444', 'Fixture', 'token-race-fixture-' || n
from generate_series(1, 19) n;
select extensions.dblink_exec('token_race', 'set role authenticated');
select extensions.dblink_exec('token_race', 'set request.jwt.claim.sub = ''44444444-4444-4444-8444-444444444444''');
select extensions.dblink_exec('token_race', 'set lock_timeout = ''300ms''');
begin;
set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-8444-444444444444';
do $$ begin perform public.mint_agent_token('Twentieth'); end $$;
reset role;
do $$ begin
  begin
    perform * from extensions.dblink('token_race', 'select public.mint_agent_token(''Concurrent'')') as t(token text);
    raise exception 'Concurrent mint bypassed the per-user lock';
  exception when lock_not_available then null;
  end;
end $$;
commit;
do $$ begin
  begin
    perform * from extensions.dblink('token_race', 'select public.mint_agent_token(''After commit'')') as t(token text);
    raise exception 'Twenty-token limit bypassed';
  exception when raise_exception then
    if sqlerrm <> 'Token limit reached' then raise; end if;
  end;
  assert (select count(*) = 20 from public.agent_tokens
    where user_id = '44444444-4444-4444-8444-444444444444' and revoked_at is null);
end $$;
select extensions.dblink_disconnect('token_race');
delete from auth.users where id = '44444444-4444-4444-8444-444444444444';
