-- Run with `supabase db query --linked --file supabase/tests/live_activity_handoff.sql`.
-- The synthetic device is never committed or visible to the push worker.
begin;
do $$
declare
  owner_id uuid;
  device_token text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  old_token text := repeat('a', 64);
  new_token text := repeat('b', 64);
  actual public.device_tokens%rowtype;
begin
  select id into strict owner_id from auth.users limit 1;
  insert into public.device_tokens(token, user_id, activity_push_token)
  values (device_token, owner_id, old_token);

  perform public.record_live_activity_start(device_token, owner_id, old_token, now(), true);
  select * into strict actual from public.device_tokens where token = device_token;
  assert actual.activity_push_token is null, 'Old update token must await replacement';
  assert actual.retiring_activity_push_token = old_token, 'Old banner must remain addressable';

  -- Simulate the phone uploading its replacement before APNs returns.
  update public.device_tokens set activity_push_token = new_token where token = device_token;
  perform public.record_live_activity_start(device_token, owner_id, old_token, now(), true);
  select * into strict actual from public.device_tokens where token = device_token;
  assert actual.activity_push_token = new_token, 'Start recording erased the replacement token';
  assert actual.retiring_activity_push_token = old_token, 'Retirement target must remain the old banner';

  -- First starts can race the upload too, with no previous token.
  perform public.record_live_activity_start(device_token, owner_id, null, now(), false);
  select * into strict actual from public.device_tokens where token = device_token;
  assert actual.activity_push_token = new_token, 'Initial start erased its update token';

  perform public.record_live_activity_start(device_token, gen_random_uuid(), new_token, now(), true);
  select * into strict actual from public.device_tokens where token = device_token;
  assert actual.activity_push_token = new_token, 'Another user changed the device';
  assert not has_function_privilege('anon', 'public.record_live_activity_start(text,uuid,text,timestamptz,boolean)', 'execute');
  assert not has_function_privilege('authenticated', 'public.record_live_activity_start(text,uuid,text,timestamptz,boolean)', 'execute');
  assert has_function_privilege('service_role', 'public.record_live_activity_start(text,uuid,text,timestamptz,boolean)', 'execute');
end;
$$;
rollback;
select 'Live Activity handoff SQL assertions passed; fixture rolled back' as result;
