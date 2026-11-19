-- Recover agent append ordering when the active board reaches the integer maximum.
create or replace function public.add_agent_reminder(p_user_id uuid, p_text text)
returns table (
  id uuid,
  user_id uuid,
  text text,
  sort_order integer,
  is_done boolean,
  created_at timestamptz,
  completed_at timestamptz,
  capacity_maximum integer,
  active_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  trimmed text := trim(p_text);
  cap_max integer;
  active integer;
  next_order integer;
  inserted public.reminders%rowtype;
begin
  if p_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if char_length(trimmed) < 1 or char_length(trimmed) > 500 then
    raise exception 'LMR_INVALID_TEXT';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user_id::text, 0));

  select least(16, greatest(1, coalesce(
    (select prefs.max_lines from public.lock_screen_prefs as prefs where prefs.user_id = p_user_id),
    6
  )))
  into cap_max;

  select count(*) into active
  from public.reminders as reminders
  where reminders.user_id = p_user_id and reminders.is_done = false;

  if active >= cap_max then
    raise exception 'LMR_CAPACITY_REACHED'
      using errcode = 'P0001',
            detail = cap_max::text;
  end if;

  select max(reminders.sort_order) into next_order
  from public.reminders as reminders
  where reminders.user_id = p_user_id and reminders.is_done = false;

  if next_order = 2147483647 then
    -- Reclaim integer headroom under the owner lock, preserving board order.
    with ranked as (
      select reminders.id,
        (row_number() over (order by reminders.sort_order, reminders.created_at, reminders.id) - 1)::integer as position
      from public.reminders as reminders
      where reminders.user_id = p_user_id and reminders.is_done = false
    )
    update public.reminders as reminders
    set sort_order = ranked.position
    from ranked
    where reminders.id = ranked.id;

    next_order := active;
  else
    next_order := coalesce(next_order, -1) + 1;
  end if;

  insert into public.reminders (user_id, text, sort_order)
  values (p_user_id, trimmed, next_order)
  returning * into inserted;

  return query
  select
    inserted.id,
    inserted.user_id,
    inserted.text,
    inserted.sort_order,
    inserted.is_done,
    inserted.created_at,
    inserted.completed_at,
    cap_max,
    active + 1;
end;
$$;

revoke all on function public.add_agent_reminder(uuid, text) from public, anon, authenticated;
grant execute on function public.add_agent_reminder(uuid, text) to service_role;
