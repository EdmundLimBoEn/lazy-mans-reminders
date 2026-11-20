begin;

-- Existing constraints enforce ASCII hex and the 64-character minimum.
-- Check only new values so a legacy token cannot block updates to its siblings.
create function public.check_activitykit_token_lengths() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (octet_length(new.push_to_start_token) > 512
      and new.push_to_start_token is distinct from old.push_to_start_token)
    or (octet_length(new.activity_push_token) > 512
      and new.activity_push_token is distinct from old.activity_push_token)
    or (octet_length(new.retiring_activity_push_token) > 512
      and new.retiring_activity_push_token is distinct from old.retiring_activity_push_token) then
    raise check_violation;
  end if;
  return new;
end;
$$;
revoke all on function public.check_activitykit_token_lengths() from public, anon, authenticated;

create trigger device_tokens_check_activitykit_lengths
before insert or update of push_to_start_token, activity_push_token, retiring_activity_push_token
on public.device_tokens for each row execute function public.check_activitykit_token_lengths();

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
      octet_length(d.push_to_start_token) <= 512
        or octet_length(d.activity_push_token) <= 512
        or octet_length(d.retiring_activity_push_token) <= 512
    else d.user_id = (new_record->>'user_id')::uuid end;
  perform public.dispatch_reminder_push_jobs();
  return null;
end;
$$;

commit;
