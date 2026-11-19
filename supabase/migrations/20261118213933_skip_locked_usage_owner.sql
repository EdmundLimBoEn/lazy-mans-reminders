create or replace function public.increment_usage_count(p_user_id uuid, p_event text, p_source text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce((select enabled from public.usage_analytics_config where singleton), false) then
    return;
  end if;
  -- Take the FK's lock before inserting. Skip a user already locked for deletion.
  insert into public.usage_daily_counts as counts(user_id, day, event, source, count)
  select id, (statement_timestamp() at time zone 'UTC')::date, p_event, p_source, 1
  from auth.users where id = p_user_id
  for key share skip locked
  on conflict (user_id, day, event, source) do update set count = counts.count + 1;
end;
$$;
