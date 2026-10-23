-- Disposable local database only. All fixtures are rolled back.
begin;
do $$
declare
  owner_id uuid := gen_random_uuid();
  device text := repeat('c', 64);
  first_lease uuid := gen_random_uuid();
  second_lease uuid := gen_random_uuid();
  started timestamptz := clock_timestamp();
  actual public.device_tokens%rowtype;
begin
  insert into auth.users(id) values (owner_id);
  insert into public.device_tokens(token, user_id) values (device, owner_id);
  assert public.claim_live_activity_start(device, owner_id, first_lease, null, null);
  assert not public.claim_live_activity_start(device, owner_id, second_lease, null, null), 'Overlapping handler acquired a live lease';
  perform public.release_live_activity_start(device, owner_id, second_lease);
  assert not public.claim_live_activity_start(device, owner_id, second_lease, null, null), 'Wrong release removed the lease';
  perform public.complete_live_activity_start(device, owner_id, null, started, false, second_lease);
  select * into strict actual from public.device_tokens where token = device;
  assert actual.activity_started_at is null, 'Wrong completion changed the device';

  -- Expired workers cannot release or complete a newer claim.
  update public.live_activity_start_leases set expires_at = clock_timestamp() - interval '1 second' where device_token = device;
  assert public.claim_live_activity_start(device, owner_id, second_lease, null, null);
  perform public.release_live_activity_start(device, owner_id, first_lease);
  perform public.complete_live_activity_start(device, owner_id, null, started, false, first_lease);
  assert not public.claim_live_activity_start(device, owner_id, first_lease, null, null);

  -- A token uploaded during delivery survives completion.
  update public.device_tokens set activity_push_token = repeat('b', 64) where token = device;
  perform public.complete_live_activity_start(device, owner_id, null, started, false, second_lease);
  select * into strict actual from public.device_tokens where token = device;
  assert actual.activity_started_at = started;
  assert actual.activity_push_token = repeat('b', 64);
  assert not public.claim_live_activity_start(device, owner_id, first_lease, null, null), 'Stale snapshot acquired a lease after completion';

  assert not public.claim_live_activity_start(device, gen_random_uuid(), first_lease, repeat('b', 64), started);
  assert public.claim_live_activity_start(device, owner_id, first_lease, repeat('b', 64), started);
  perform public.release_live_activity_start(device, owner_id, first_lease);
  assert public.claim_live_activity_start(device, owner_id, second_lease, repeat('b', 64), started), 'Failed delivery could not retry';
  perform public.complete_live_activity_start(device, owner_id, repeat('b', 64), started + interval '7 hours', true, second_lease);
  select * into strict actual from public.device_tokens where token = device;
  assert actual.activity_push_token is null;
  assert actual.retiring_activity_push_token = repeat('b', 64);
  assert not has_table_privilege('authenticated', 'public.live_activity_start_leases', 'UPDATE');
  assert not has_function_privilege('authenticated', 'public.claim_live_activity_start(text,uuid,uuid,text,timestamptz)', 'EXECUTE');
  assert not has_function_privilege('anon', 'public.complete_live_activity_start(text,uuid,text,timestamptz,boolean,uuid)', 'EXECUTE');
  assert not has_function_privilege('authenticated', 'public.release_live_activity_start(text,uuid,uuid)', 'EXECUTE');
end;
$$;
rollback;
