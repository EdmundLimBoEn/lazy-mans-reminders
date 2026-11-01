-- Disposable database only. Transport is replaced transactionally; no HTTP calls.
begin;
create or replace function public.post_reminder_push(payload jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
begin
  raise exception 'simulated transport outage';
end;
$$;
do $$
declare
  owner_id uuid := gen_random_uuid();
  device text := repeat('a', 64);
  second_device text := repeat('b', 64);
  event jsonb;
  job_id uuid;
begin
  insert into auth.users(id) values (owner_id);
  insert into public.device_tokens(token, user_id) values
    (device, owner_id), (second_device, owner_id);
  event := jsonb_build_object('type', 'INSERT', 'schema', 'public', 'table', 'reminders',
    'record', jsonb_build_object('id', gen_random_uuid(), 'user_id', owner_id, 'text', 'Test'));
  perform public.request_reminder_push(event);
  assert (select count(*) = 2 from public.reminder_push_jobs where user_id = owner_id);
  assert (select bool_and(attempts = 1 and status = 'pending' and payload = event)
    from public.reminder_push_jobs where user_id = owner_id), 'Submission failure lost the event';
  perform public.dispatch_reminder_push_jobs();
  assert (select bool_and(attempts = 1) from public.reminder_push_jobs where user_id = owner_id),
    'Backoff was bypassed';
  update public.reminder_push_jobs set status = 'complete' where device_token = device;
  update public.reminder_push_jobs set next_attempt_at = now() - interval '1 second'
    where user_id = owner_id;
  perform public.dispatch_reminder_push_jobs();
  assert (select attempts = 1 from public.reminder_push_jobs where device_token = device),
    'Successful device was replayed';
  assert (select attempts = 2 and next_attempt_at >= now() + interval '239 seconds'
    from public.reminder_push_jobs where device_token = second_device), 'Retry did not back off';
  update public.reminder_push_jobs set attempts = 11, next_attempt_at = now() - interval '1 second'
    where device_token = second_device returning id into job_id;
  perform public.dispatch_reminder_push_jobs();
  assert (select attempts = 12 and next_attempt_at <= clock_timestamp() + interval '1 hour'
    from public.reminder_push_jobs where id = job_id), 'Backoff was not bounded';
  update public.reminder_push_jobs set next_attempt_at = now() - interval '1 second' where id = job_id;
  perform public.dispatch_reminder_push_jobs();
  assert (select status = 'exhausted' and attempts = 12 from public.reminder_push_jobs where id = job_id);
  assert not has_table_privilege('authenticated', 'public.reminder_push_jobs', 'SELECT');
  assert not has_table_privilege('anon', 'public.reminder_push_jobs', 'UPDATE');
  assert not has_function_privilege('authenticated', 'public.dispatch_reminder_push_jobs()', 'EXECUTE');
  assert not has_function_privilege('anon', 'public.post_reminder_push(jsonb)', 'EXECUTE');
  delete from auth.users where id = owner_id;
  assert not exists (select 1 from public.reminder_push_jobs where user_id = owner_id);
end;
$$;
rollback;
