-- Disposable database only; CI preloads pg_cron and applies this migration twice.
begin;
do $$
declare
  job cron.job%rowtype;
begin
  assert (select count(*) = 1 from cron.job
    where jobname = 'cleanup-old-completed-reminders'),
    'Re-applying the migration must leave exactly one retention job';
  select * into strict job from cron.job
    where jobname = 'cleanup-old-completed-reminders';
  assert job.schedule = '43 * * * *', 'Run hourly away from usage cleanup';
  assert job.command = 'select public.delete_old_completed_reminders();';
  assert job.active, 'Retention job must be enabled';
  assert job.database = current_database();
  assert job.username = current_user, 'Cron must run as the migration owner';
  assert has_function_privilege(job.username,
    'public.delete_old_completed_reminders()', 'execute');
  assert (select rolsuper or rolbypassrls from pg_roles where rolname = job.username),
    'Invoker cleanup needs a cron role that can bypass owner RLS';
  assert has_function_privilege('authenticated',
    'public.delete_old_completed_reminders()', 'execute');
  assert has_function_privilege('service_role',
    'public.delete_old_completed_reminders()', 'execute');
  assert not has_function_privilege('anon',
    'public.delete_old_completed_reminders()', 'execute');
end $$;
rollback;
