begin;

alter table public.usage_daily_counts drop constraint usage_daily_counts_event_check;
alter table public.usage_daily_counts add constraint usage_daily_counts_event_check check (event in (
  'reminder_created', 'reminder_deleted', 'reminder_completed',
  'agent_token_created', 'agent_token_revoked', 'agent_token_deleted',
  'mcp_list', 'mcp_add', 'mcp_edit', 'mcp_complete', 'mcp_reopen', 'mcp_whoami',
  'agent_oauth_connected'
));

create or replace function public.record_agent_usage(p_user_id uuid, p_event text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce((select enabled from public.usage_analytics_config where singleton), false) then return; end if;
  if p_event is null or p_event not in ('mcp_list', 'mcp_add', 'mcp_edit', 'mcp_complete',
      'mcp_reopen', 'mcp_whoami', 'agent_oauth_connected') then
    raise invalid_parameter_value using message = 'Invalid analytics event';
  end if;
  perform public.increment_usage_count(p_user_id, p_event, 'agent');
end;
$$;
revoke all on function public.record_agent_usage(uuid,text) from public, anon, authenticated;
grant execute on function public.record_agent_usage(uuid,text) to service_role;

commit;
