begin;

-- Supabase no longer grants API roles table access by default. These client
-- grants let the existing owner-only policies control access.
grant select, insert, update, delete
  on public.reminders, public.device_tokens, public.lock_screen_prefs to authenticated;

-- MCP board edits and invoker RPCs, and push delivery and token pruning.
grant select, delete on public.reminders, public.device_tokens to service_role;
grant update (text, is_done) on public.reminders to service_role;
grant update (push_to_start_token, activity_push_token, activity_started_at, retiring_activity_push_token)
  on public.device_tokens to service_role;
grant select (user_id, max_lines) on public.lock_screen_prefs to service_role;

-- Personal-token authentication reads the hash and records successful use.
grant select (id, user_id, name, token_hash, revoked_at), update (last_used_at)
  on public.agent_tokens to service_role;

commit;
