begin;

-- pg_cron is already required by earlier migrations. Run as the migration
-- owner, as with the other cron jobs, so invoker cleanup can reach all owners.
-- Explicit replacement also handles a re-apply or a manually created job.
select cron.unschedule(jobid)
from cron.job
where jobname = 'cleanup-old-completed-reminders';

-- Offset from usage cleanup at minute 17; retain client board-load cleanup.
select cron.schedule(
  'cleanup-old-completed-reminders',
  '43 * * * *',
  'select public.delete_old_completed_reminders();'
);

commit;
