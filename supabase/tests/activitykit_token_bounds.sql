-- Disposable local database only. Queue jobs without contacting the transport.
begin;
create or replace function public.post_reminder_push(payload jsonb) returns bigint
language sql as $$ select 1::bigint $$;

do $$
declare
  owner_id uuid := gen_random_uuid();
  device text := repeat('1', 64);
  token_column text;
begin
  insert into auth.users(id) values (owner_id);
  foreach token_column in array array['push_to_start_token', 'activity_push_token', 'retiring_activity_push_token']
  loop
    execute format('insert into public.device_tokens(user_id, token, %I) values ($1, $2, $3)', token_column)
      using owner_id, device, repeat('F', 512);
    perform public.request_reminder_push('{"type":"live_activity_refresh"}');
    assert (select count(*) = 1 from public.reminder_push_jobs where device_token = device),
      format('A 512-character %s alone should receive a refresh', token_column);

    begin
      execute format('update public.device_tokens set %I = $1 where token = $2', token_column)
        using repeat('a', 513), device;
      raise exception 'Accepted oversized % on update', token_column;
    exception when check_violation then null;
    end;
    delete from public.device_tokens where token = device;
    begin
      execute format('insert into public.device_tokens(user_id, token, %I) values ($1, $2, $3)', token_column)
        using owner_id, device, repeat('a', 513);
      raise exception 'Accepted oversized % on insert', token_column;
    exception when check_violation then null;
    end;
  end loop;
end $$;

do $$
declare
  owner_id uuid := gen_random_uuid();
  oversized text := repeat('a', 513);
  mixed_device text := repeat('1', 64);
begin
  insert into auth.users(id) values (owner_id);
  -- Reconstruct registrations written before the bounds were enforced.
  set local session_replication_role = replica;
  insert into public.device_tokens(user_id, token, push_to_start_token, activity_push_token, retiring_activity_push_token)
  values (owner_id, mixed_device, oversized, null, null),
         (owner_id, repeat('2', 64), null, oversized, null),
         (owner_id, repeat('3', 64), null, null, oversized),
         (owner_id, repeat('4', 64), null, null, null);
  set local session_replication_role = origin;
  perform public.request_reminder_push('{"type":"live_activity_refresh"}');
  assert not exists (select from public.reminder_push_jobs where user_id = owner_id),
    'Devices without a usable ActivityKit token should not receive a refresh';

  update public.device_tokens set activity_push_token = repeat('b', 64) where token = mixed_device;
  perform public.request_reminder_push('{"type":"live_activity_refresh"}');
  assert (select count(*) = 1 and bool_and(device_token = mixed_device)
          from public.reminder_push_jobs where user_id = owner_id),
    'A usable token alongside an oversized legacy token should receive a refresh';
end $$;
rollback;
