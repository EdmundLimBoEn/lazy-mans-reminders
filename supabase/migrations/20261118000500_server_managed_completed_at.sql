begin;

-- Replace each existing table-wide write grant with the same access to the
-- other columns. Installations with narrower grants keep those restrictions.
do $$
declare
  other_columns text;
  write_privilege text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position)
    into other_columns
    from information_schema.columns
    where table_schema = 'public' and table_name = 'reminders' and column_name <> 'completed_at';

  foreach write_privilege in array array['INSERT', 'UPDATE'] loop
    if has_table_privilege('authenticated', 'public.reminders', write_privilege) then
      execute format('revoke %s on public.reminders from authenticated', write_privilege);
      execute format('grant %s (%s) on public.reminders to authenticated', write_privilege, other_columns);
    end if;
  end loop;
end $$;

revoke insert (completed_at), update (completed_at) on public.reminders from authenticated;

commit;
