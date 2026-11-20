begin;

create or replace function public.request_reminder_push(payload jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
begin
  -- A DELETE refresh needs only the owner. Discard row snapshots before fan-out.
  if payload->>'type' = 'DELETE' then
    payload := jsonb_build_object(
      'type', 'DELETE', 'table', payload->'table', 'schema', payload->'schema',
      'record', jsonb_build_object('user_id', payload->'record'->'user_id')
    );
  end if;

  insert into public.reminder_push_jobs(user_id, device_token, payload)
    select d.user_id, d.token, payload from public.device_tokens d
    where case when payload->>'type' = 'live_activity_refresh' then
      d.push_to_start_token is not null or d.activity_push_token is not null
        or d.retiring_activity_push_token is not null
    else d.user_id = (payload->'record'->>'user_id')::uuid end;
  perform public.dispatch_reminder_push_jobs();
  return null;
end;
$$;

commit;
