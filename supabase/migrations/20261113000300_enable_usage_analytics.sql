begin;

-- Starts database collection immediately; MCP tool/OAuth telemetry also needs
-- the Worker USAGE_ANALYTICS_ENABLED=true variable and a Worker deployment.
insert into public.usage_analytics_config(singleton, enabled)
values (true, true)
on conflict (singleton) do update set enabled = excluded.enabled;

commit;
