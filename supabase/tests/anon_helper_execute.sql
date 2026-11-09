-- Run after migrations against a disposable database. All fixtures roll back.
begin;
do $$ begin
  assert not has_function_privilege(
    'anon', 'public.delete_old_completed_reminders()', 'execute'),
    'anon must not keep the default EXECUTE grant on delete_old_completed_reminders';
  assert has_function_privilege(
    'authenticated', 'public.delete_old_completed_reminders()', 'execute'),
    'board load still calls delete_old_completed_reminders signed in';
  assert not has_function_privilege(
    'anon',
    'public.next_routine_run(date,time,text,integer,timestamptz)',
    'execute');
  assert has_function_privilege(
    'authenticated',
    'public.next_routine_run(date,time,text,integer,timestamptz)',
    'execute');
  assert not has_function_privilege(
    'anon', 'public.prepare_routine_schedule()', 'execute');
  assert not has_function_privilege('anon', 'public.set_completed_at()', 'execute');
  assert not has_function_privilege('anon', 'public.set_updated_at()', 'execute');
  assert not has_function_privilege(
    'anon', 'public.track_live_activity_start()', 'execute');
end $$;
rollback;
