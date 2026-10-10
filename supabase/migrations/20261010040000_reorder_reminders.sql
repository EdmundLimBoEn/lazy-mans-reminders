create or replace function public.reorder_reminders(p_ids uuid[])
returns setof public.reminders
language plpgsql
security invoker
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  active_count integer;
begin
  if owner_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(owner_id::text, 0));
  perform 1 from public.reminders
    where user_id = owner_id and is_done = false for update;

  select count(*) into active_count from public.reminders
    where user_id = owner_id and is_done = false;
  if p_ids is null
    or cardinality(p_ids) <> active_count
    or (select count(distinct id) from unnest(p_ids) as requested(id)) <> active_count
    or exists (
      select 1 from unnest(p_ids) as requested(id)
      where not exists (
        select 1 from public.reminders
        where reminders.id = requested.id and user_id = owner_id and is_done = false
      )
    ) then
    raise exception 'The board changed. Refresh and try reordering again.';
  end if;

  update public.reminders as reminder
    set sort_order = requested.position - 1
    from unnest(p_ids) with ordinality as requested(id, position)
    where reminder.id = requested.id and reminder.user_id = owner_id and reminder.is_done = false;

  return query select * from public.reminders
    where user_id = owner_id and is_done = false
    order by sort_order, created_at, id;
end;
$$;

revoke all on function public.reorder_reminders(uuid[]) from public, anon;
grant execute on function public.reorder_reminders(uuid[]) to authenticated;
