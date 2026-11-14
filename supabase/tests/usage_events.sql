-- Run with psql -v ON_ERROR_STOP=1 after migrations on a disposable database.
-- All fixtures and replacements roll back; never sends fixture pushes.
begin;
create or replace function public.request_reminder_push(payload jsonb) returns bigint
language sql as $$ select 1::bigint $$;
insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');

do $$
declare
  owner_id uuid := '11111111-1111-4111-8111-111111111111';
  other_id uuid := '22222222-2222-4222-8222-222222222222';
  row_id uuid;
  agent_id uuid;
  token_id uuid;
  today date := (statement_timestamp() at time zone 'UTC')::date;
  report record;
  before_count bigint;
  role_name text;
  signature text;
begin
  assert not (select enabled from public.usage_analytics_config), 'Collection must default off';
  insert into public.reminders(user_id, text) values (owner_id, 'Disabled') returning id into row_id;
  update public.reminders set is_done = true where id = row_id;
  delete from public.reminders where id = row_id;
  perform public.record_agent_usage(owner_id, 'mcp_list');
  perform public.record_agent_usage(owner_id, 'mcp_edit');
  assert not exists (select 1 from public.usage_daily_counts), 'Disabled triggers/RPC wrote data';

  update public.usage_analytics_config set enabled = true;
  perform set_config('request.headers', '{"x-notepad-client":"web"}', true);
  perform set_config('request.jwt.claims', '{"role":"authenticated"}', true);
  insert into public.reminders(user_id, text) values (owner_id, 'Created') returning id into row_id;
  update public.reminders set text = 'Edited', sort_order = 7 where id = row_id;
  update public.reminders set is_done = false where id = row_id;
  assert (select sum(count) = 1 from public.usage_daily_counts), 'Edit/reorder/no-op counted';
  perform set_config('request.headers', '{"x-notepad-client":"ios"}', true);
  update public.reminders set is_done = true where id = row_id;
  update public.reminders set is_done = true where id = row_id;
  assert (select count = 1 from public.usage_daily_counts where event = 'reminder_completed'),
    'Completion retry double counted';
  update public.reminders set is_done = false where id = row_id;
  update public.reminders set is_done = true where id = row_id;
  assert (select count = 2 from public.usage_daily_counts where event = 'reminder_completed'),
    'Second real completion missing';
  delete from public.reminders where id = row_id;
  assert (select count = 1 and source = 'ios' from public.usage_daily_counts where event = 'reminder_deleted');

  -- Agent RPC marks only its insertion, then restores the previous request context.
  select id into agent_id from public.add_agent_reminder(owner_id, 'Agent');
  assert (select count = 1 from public.usage_daily_counts where event = 'reminder_created' and source = 'agent');
  assert public.usage_request_source() = 'ios', 'Agent context leaked after RPC';
  perform set_config('request.headers', '{"x-notepad-client":"agent"}', true);
  assert public.usage_request_source() = 'unknown', 'End user forged agent source';
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  update public.reminders set is_done = true where id = agent_id;
  assert (select count = 1 from public.usage_daily_counts where event = 'reminder_completed' and source = 'agent');
  perform set_config('request.headers', 'not json', true);
  assert public.usage_request_source() = 'unknown';
  perform set_config('request.headers', '{"x-notepad-client":"arbitrary"}', true);
  assert public.usage_request_source() = 'unknown';
  perform set_config('request.headers', '', true);
  insert into public.reminders(user_id, text, is_done) values (other_id, 'Legacy', true);
  assert (select source = 'unknown' from public.usage_daily_counts where user_id = other_id);

  -- Failed transactions and upsert UPDATE branches must not invent creations.
  select sum(count) into before_count from public.usage_daily_counts;
  begin
    insert into public.reminders(user_id, text) values (owner_id, 'Rolled back');
    raise exception using errcode = 'P1234', message = 'test rollback';
  exception when sqlstate 'P1234' then null;
  end;
  insert into public.reminders(id, user_id, text, is_done) values (agent_id, owner_id, 'Upsert', true)
  on conflict (id) do update set text = excluded.text;
  assert (select sum(count) = before_count from public.usage_daily_counts), 'Rollback/upsert polluted counts';

  insert into public.agent_tokens(user_id, name, token_hash)
    values (owner_id, 'Synthetic', 'usage-test-hash') returning id into token_id;
  update public.agent_tokens set last_used_at = now() where id = token_id;
  update public.agent_tokens set revoked_at = now() where id = token_id;
  update public.agent_tokens set revoked_at = now() where id = token_id;
  delete from public.agent_tokens where id = token_id;
  assert (select sum(count) = 3 from public.usage_daily_counts where event like 'agent_token_%');
  perform public.record_agent_usage(owner_id, 'mcp_list');
  perform public.record_agent_usage(owner_id, 'mcp_list');
  perform public.record_agent_usage(owner_id, 'agent_oauth_connected');
  perform public.record_agent_usage(owner_id, 'mcp_edit');
  assert (select count = 1 and source = 'agent' from public.usage_daily_counts
    where user_id = owner_id and event = 'mcp_edit');
  begin
    perform public.record_agent_usage(owner_id, 'reminder_created');
    raise exception 'Ingest accepted a non-agent event';
  exception when invalid_parameter_value then null;
  end;
  select * into strict report from public.usage_daily_report(today, today) where user_id = owner_id;
  assert report.created = 2 and report.deleted = 1 and report.completed = 3;
  select * into strict report from public.usage_abuse_report(today, 2, 1, 1) where user_id = owner_id;
  assert report.high_creates and report.high_deletes and report.high_stored;
  assert report.stored = 1 and report.active = 0;
  assert (select events = 2 and users = 1 from public.usage_source_report(today, today)
    where event = 'mcp_list' and source = 'agent');

  -- Date retention, bounded batches, disabled cleanup, and account deletion.
  insert into public.usage_daily_counts values
    (owner_id, today - 90, 'mcp_list', 'agent', 1),
    (other_id, today - 91, 'mcp_list', 'agent', 1),
    (owner_id, today - 89, 'mcp_list', 'agent', 1);
  update public.usage_analytics_config set enabled = false;
  assert public.cleanup_usage_counts(1) = 1;
  assert public.cleanup_usage_counts() = 1;
  assert exists (select 1 from public.usage_daily_counts where day = today - 89);
  select sum(count) into before_count from public.usage_daily_counts;
  perform public.record_agent_usage(owner_id, 'mcp_list');
  perform public.record_agent_usage(owner_id, 'mcp_edit');
  update public.reminders set is_done = false where id = agent_id;
  update public.reminders set is_done = true where id = agent_id;
  assert (select sum(count) = before_count from public.usage_daily_counts), 'Disable did not stop collection';
  update public.usage_analytics_config set enabled = true;
  delete from auth.users where id = owner_id;
  perform public.record_agent_usage(owner_id, 'mcp_list');
  perform public.record_agent_usage(owner_id, 'mcp_edit');
  assert not exists (select 1 from public.usage_daily_counts where user_id = owner_id), 'Deleted account history survived';
  assert exists (select 1 from public.usage_daily_counts where user_id = other_id), 'Other account history lost';

  foreach role_name in array array['anon', 'authenticated'] loop
    assert not has_table_privilege(role_name, 'public.usage_daily_counts', 'SELECT');
    assert not has_table_privilege(role_name, 'public.usage_daily_counts', 'INSERT');
    assert not has_table_privilege(role_name, 'public.usage_analytics_config', 'UPDATE');
    foreach signature in array array[
      'public.record_agent_usage(uuid,text)', 'public.increment_usage_count(uuid,text,text)',
      'public.usage_request_source()', 'public.capture_usage_change()',
      'public.usage_daily_report(date,date)', 'public.usage_source_report(date,date)',
      'public.usage_abuse_report(date,integer,integer,integer)', 'public.cleanup_usage_counts(integer)'
    ] loop
      assert not has_function_privilege(role_name, signature, 'EXECUTE'), role_name || ' can execute ' || signature;
    end loop;
  end loop;
  assert has_function_privilege('service_role', 'public.usage_daily_report(date,date)', 'EXECUTE');
  assert not has_function_privilege('service_role', 'public.increment_usage_count(uuid,text,text)', 'EXECUTE');
  assert (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.usage_daily_counts'::regclass);
  assert not exists (select 1 from pg_policies where tablename in ('usage_daily_counts', 'usage_analytics_config'));
end $$;

-- Exercise actual role boundaries rather than relying only on grant metadata.
set local role authenticated;
do $$ begin
  begin
    perform * from public.usage_daily_counts;
    raise exception 'User read analytics';
  exception when insufficient_privilege then null; end;
  begin
    perform public.record_agent_usage('22222222-2222-4222-8222-222222222222', 'mcp_list');
    raise exception 'User wrote analytics';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role service_role;
select * from public.usage_daily_report(current_date - 1, current_date + 1);
select * from public.usage_source_report(current_date - 1, current_date + 1);
select * from public.usage_abuse_report();
select public.record_agent_usage('22222222-2222-4222-8222-222222222222', 'mcp_whoami');
reset role;
rollback;
