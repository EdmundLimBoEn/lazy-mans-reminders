-- Supabase default privileges grant EXECUTE to anon as a role grant.
-- REVOKE FROM PUBLIC does not drop that (see 20261008035839). Clients call
-- delete_old_completed_reminders as authenticated; next_routine_run is
-- trigger-only. Trigger helpers stay executable by authenticated.
revoke execute on function public.delete_old_completed_reminders() from public, anon;
revoke execute on function public.next_routine_run(date, time, text, integer, timestamptz)
  from public, anon;
revoke execute on function public.prepare_routine_schedule() from public, anon;
revoke execute on function public.set_completed_at() from public, anon;
revoke execute on function public.set_updated_at() from public, anon;
revoke execute on function public.track_live_activity_start() from public, anon;
grant execute on function public.delete_old_completed_reminders() to authenticated, service_role;
grant execute on function public.next_routine_run(date, time, text, integer, timestamptz)
  to authenticated, service_role;
