-- Disposable database only; every fixture and helper rolls back.
begin;
create function pg_temp.expect_rate_limited(command text) returns void
language plpgsql as $$ begin
  begin
    execute command;
    raise exception 'Write unexpectedly bypassed the budget: %', command;
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'rate_limited' then raise; end if;
  end;
end $$;

insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');
insert into public.agent_tokens(id, user_id, name, token_hash) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', '11111111-1111-4111-8111-111111111111', 'Revoke fixture', 'revocation-fixture-1'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', '11111111-1111-4111-8111-111111111111', 'Delete fixture', 'revocation-fixture-2'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', '22222222-2222-4222-8222-222222222222', 'Other owner', 'revocation-fixture-3');
-- Fix the window in the future so a minute boundary cannot replenish it.
update public.user_write_budgets
set writes = 599, window_started_at = statement_timestamp() + interval '1 hour';

-- Background personal-token bookkeeping can still consume the last write.
set local role service_role;
set local request.jwt.claim.sub = '';
update public.agent_tokens set last_used_at = now()
where id in ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3');
do $$ begin
  perform pg_temp.expect_rate_limited($q$
    update public.agent_tokens set last_used_at = now()
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
  $q$);
  perform pg_temp.expect_rate_limited($q$
    update public.agent_tokens set revoked_at = now()
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
  $q$);
  perform pg_temp.expect_rate_limited($q$
    delete from public.agent_tokens where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
  $q$);
end $$;
reset role;

set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
do $$ begin
  assert not public.revoke_agent_token('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
    'Revocation must still enforce ownership';
  delete from public.agent_tokens where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3';
  assert not found, 'Deletion must still enforce owner RLS';

  assert public.revoke_agent_token('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'),
    'Owner must be able to revoke with an exhausted budget';
  assert not public.revoke_agent_token('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'),
    'Repeated revocation remains a no-op';
  assert exists (select 1 from public.agent_tokens
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1' and revoked_at is not null);

  perform pg_temp.expect_rate_limited($q$select public.mint_agent_token('Over budget')$q$);
  perform pg_temp.expect_rate_limited($q$
    insert into public.reminders(user_id, text) values (auth.uid(), 'Over budget')
  $q$);
end $$;
reset role;

-- Even with the owner's claim, other token changes must remain budgeted.
set local role service_role;
do $$ begin
  perform pg_temp.expect_rate_limited($q$
    update public.agent_tokens set revoked_at = null
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
  $q$);
  perform pg_temp.expect_rate_limited($q$
    update public.agent_tokens set revoked_at = now(), name = 'Changed'
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'
  $q$);
  perform pg_temp.expect_rate_limited($q$
    update public.agent_tokens set name = 'Changed'
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'
  $q$);
  perform pg_temp.expect_rate_limited($q$
    update public.agent_tokens set revoked_at = now()
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'
  $q$);
end $$;
reset role;

set local role authenticated;
do $$ begin
  delete from public.agent_tokens where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  assert found, 'Owner must be able to delete a revoked credential';
  delete from public.agent_tokens where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  assert found, 'Owner must be able to delete an active credential';
end $$;
set local request.jwt.claim.sub = '';
do $$ begin
  begin
    perform public.revoke_agent_token('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3');
    raise exception 'Revocation accepted a missing identity';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'Not authenticated' then raise; end if;
  end;
end $$;
reset role;
do $$ begin
  assert (select count(*) = 2 and bool_and(writes = 600) from public.user_write_budgets),
    'Credential removal must not charge or reset the exhausted budgets';
  assert (select count(*) = 1 from public.agent_tokens);
  assert exists (select 1 from public.agent_tokens
    where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3' and revoked_at is null),
    'The other owner token must remain active';
  assert not has_function_privilege('authenticated', 'public.enforce_user_write_budget()', 'execute');
  assert not has_function_privilege('anon', 'public.revoke_agent_token(uuid)', 'execute');
end $$;
rollback;
