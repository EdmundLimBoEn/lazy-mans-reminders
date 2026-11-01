begin;

create or replace function public.reopen_reminder(p_user_id uuid, p_reminder_id uuid, p_text text default null)
returns setof public.reminders
language plpgsql security invoker set search_path = '' as $$
begin
  if p_user_id is null or (current_user <> 'service_role' and
      p_user_id is distinct from auth.uid()) then
    return;
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user_id::text, 0));
  return query update public.reminders
    set is_done = false, text = coalesce(p_text, text)
    where id = p_reminder_id and user_id = p_user_id
      and (is_done or (p_text is not null and p_text is distinct from text))
    returning *;
  if not found then
    -- Return an unchanged owned row without firing mutation/budget triggers.
    return query select * from public.reminders
      where id = p_reminder_id and user_id = p_user_id and not is_done;
  end if;
end;
$$;
revoke all on function public.reopen_reminder(uuid, uuid, text) from public, anon;
grant execute on function public.reopen_reminder(uuid, uuid, text) to authenticated, service_role;

commit;
