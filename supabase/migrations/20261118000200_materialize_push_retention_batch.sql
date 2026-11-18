create or replace function public.cleanup_reminder_push_jobs() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  deleted_count integer;
begin
  -- Fix the candidate set before deleting so rescans cannot refill the batch.
  with expired as materialized (
    select id from public.reminder_push_jobs
    where created_at < now() - interval '7 days'
    order by created_at
    limit 1000 for update skip locked
  )
  delete from public.reminder_push_jobs j using expired
  where j.id = expired.id;
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;
