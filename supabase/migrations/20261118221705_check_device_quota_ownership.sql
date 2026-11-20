begin;

-- Check ownership as the writer before entering the SECURITY DEFINER
-- function. RLS still rejects mismatched client writes.
create or replace trigger device_tokens_enforce_quota
  before insert or update of user_id on public.device_tokens
  for each row when (
    case current_user
      when 'anon' then false
      when 'authenticated' then new.user_id = auth.uid()
      else true
    end
  )
  execute function public.enforce_device_token_quota();

commit;
