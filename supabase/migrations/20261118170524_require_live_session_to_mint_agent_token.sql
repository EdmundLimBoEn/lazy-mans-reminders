create or replace function public.mint_agent_token(p_name text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  trimmed_name text := trim(p_name);
  active_count integer;
  secret text;
  new_id uuid;
  hash text;
begin
  -- Sign-out removes the session even while its access token is still valid.
  if uid is null or not exists (
    select 1 from auth.sessions as s
    where s.user_id = uid
      and s.id::text = (select auth.jwt()->>'session_id')
      and (s.not_after is null or s.not_after > statement_timestamp())
  ) then
    raise exception 'Not authenticated';
  end if;
  if char_length(trimmed_name) < 1 or char_length(trimmed_name) > 64 then
    raise exception 'Invalid token name';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text, 0));

  select count(*) into active_count
  from public.agent_tokens
  where user_id = uid and revoked_at is null;

  if active_count >= 20 then
    raise exception 'Token limit reached';
  end if;

  secret := replace(
    replace(rtrim(encode(extensions.gen_random_bytes(24), 'base64'), '='), '+', '-'),
    '/',
    '_'
  );
  new_id := pg_catalog.gen_random_uuid();
  hash := encode(extensions.digest(convert_to(secret, 'UTF8'), 'sha256'), 'hex');

  insert into public.agent_tokens (id, user_id, name, token_hash)
  values (new_id, uid, trimmed_name, hash);

  return 'lmr_' || new_id::text || '_' || secret;
end;
$$;
