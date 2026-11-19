-- Supabase default privileges grant ALL on new public views to anon. The
-- original agent_tokens migration revoked the table but not this view.
-- Signed-in clients only SELECT it; the hashed secret stays on agent_tokens.
revoke all on public.agent_token_clients from public, anon;
grant select on public.agent_token_clients to authenticated;
