-- Supabase default privileges grant EXECUTE on new public functions to anon.
-- The web board calls these RPCs only as a signed-in user, so anon (and PUBLIC)
-- must not reach these SECURITY DEFINER functions.
revoke execute on function public.mint_agent_token(text) from public, anon;
revoke execute on function public.revoke_agent_token(uuid) from public, anon;
grant execute on function public.mint_agent_token(text) to authenticated, service_role;
grant execute on function public.revoke_agent_token(uuid) to authenticated, service_role;
