begin;

-- Evaluate ownership as the writer before entering the SECURITY DEFINER
-- functions. RLS rejects mismatched client writes after the BEFORE triggers.
create or replace trigger reminders_enforce_quota
  before insert or update of is_done, user_id on public.reminders
  for each row when (
    case current_user
      when 'anon' then false
      when 'authenticated' then new.user_id = auth.uid()
      else true
    end
  )
  execute function public.enforce_reminder_quota();

create or replace trigger routines_enforce_quota
  before insert on public.routine_reminders
  for each row when (
    case current_user
      when 'anon' then false
      when 'authenticated' then new.user_id = auth.uid()
      else true
    end
  )
  execute function public.enforce_routine_quota();

commit;
