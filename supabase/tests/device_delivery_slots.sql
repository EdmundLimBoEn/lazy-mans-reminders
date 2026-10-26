-- Disposable local database only. All fixtures are rolled back.
begin;
do $$
declare
  owner_id uuid := gen_random_uuid();
  device text := repeat('d', 64);
  other_device text := repeat('e', 64);
  first_lease uuid := gen_random_uuid();
  second_lease uuid := gen_random_uuid();
begin
  insert into auth.users(id) values (owner_id);
  insert into public.device_tokens(token, user_id) values (device, owner_id), (other_device, owner_id);
  assert not public.claim_device_delivery(device, gen_random_uuid(), first_lease), 'Wrong owner claimed delivery';
  assert public.claim_device_delivery(device, owner_id, first_lease);
  assert not public.claim_device_delivery(device, owner_id, second_lease), 'Overlapping invocation claimed delivery';
  assert public.claim_device_delivery(other_device, owner_id, second_lease), 'Unrelated device was blocked';
  perform public.release_device_delivery(device, owner_id, second_lease);
  assert not public.claim_device_delivery(device, owner_id, second_lease), 'Wrong lease released delivery';
  perform public.release_device_delivery(device, gen_random_uuid(), first_lease);
  assert not public.claim_device_delivery(device, owner_id, second_lease), 'Wrong owner released delivery';
  perform public.release_device_delivery(device, owner_id, first_lease);
  assert public.claim_device_delivery(device, owner_id, second_lease), 'Completed delivery blocked next invocation';

  update public.device_delivery_slots set expires_at = clock_timestamp() - interval '1 second' where device_token = device;
  assert public.claim_device_delivery(device, owner_id, first_lease), 'Abandoned slot did not expire';
  perform public.release_device_delivery(device, owner_id, second_lease);
  assert not public.claim_device_delivery(device, owner_id, second_lease), 'Expired worker released successor';

  delete from public.device_tokens where token = device;
  assert not exists (select 1 from public.device_delivery_slots where device_token = device);
  assert not public.claim_device_delivery(device, owner_id, second_lease);
  assert not has_table_privilege('authenticated', 'public.device_delivery_slots', 'UPDATE');
  assert not has_function_privilege('authenticated', 'public.claim_device_delivery(text,uuid,uuid)', 'EXECUTE');
  assert not has_function_privilege('anon', 'public.release_device_delivery(text,uuid,uuid)', 'EXECUTE');
end;
$$;
rollback;
