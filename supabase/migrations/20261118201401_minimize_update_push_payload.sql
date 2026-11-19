begin;

create or replace function public.request_reminder_push(payload jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  event_type text := payload->>'type';
  new_record jsonb := payload->'record';
  previous_firing jsonb := payload->'old_record'->'routine_fired_at';
begin
  if event_type = 'UPDATE' and new_record->>'routine_id' is not null
    and new_record->>'routine_fired_at' is not null
    and new_record->'routine_fired_at' <> previous_firing then
    -- Routine alerts need the current alert fields and the previous firing timestamp.
    payload := jsonb_build_object(
      'type', event_type, 'table', payload->'table', 'schema', payload->'schema',
      'record', jsonb_build_object(
        'id', new_record->'id', 'user_id', new_record->'user_id', 'text', new_record->'text',
        'routine_id', new_record->'routine_id', 'routine_fired_at', new_record->'routine_fired_at'
      ),
      'old_record', jsonb_build_object('routine_fired_at', previous_firing)
    );
  elsif event_type in ('UPDATE', 'DELETE') then
    -- Board refreshes need only the owner. Discard row snapshots before fan-out.
    payload := jsonb_build_object(
      'type', event_type, 'table', payload->'table', 'schema', payload->'schema',
      'record', jsonb_build_object('user_id', new_record->'user_id')
    );
  end if;

  insert into public.reminder_push_jobs(user_id, device_token, payload)
    select d.user_id, d.token, payload from public.device_tokens d
    where case when event_type = 'live_activity_refresh' then
      d.push_to_start_token is not null or d.activity_push_token is not null
        or d.retiring_activity_push_token is not null
    else d.user_id = (new_record->>'user_id')::uuid end;
  perform public.dispatch_reminder_push_jobs();
  return null;
end;
$$;

commit;
