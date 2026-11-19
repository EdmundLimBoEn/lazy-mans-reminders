-- Run after migrations against a disposable database. All fixtures roll back.
begin;
do $$ begin
  -- Hosted default privileges grant ALL on this view to anon. The table is
  -- already revoked, so this asserts the view grant itself, not row access.
  assert not has_table_privilege('anon', 'public.agent_token_clients', 'SELECT'),
    'anon must not keep the default SELECT grant on agent_token_clients';
  assert not has_table_privilege('anon', 'public.agent_token_clients', 'INSERT');
  assert not has_table_privilege('anon', 'public.agent_token_clients', 'UPDATE');
  assert not has_table_privilege('anon', 'public.agent_token_clients', 'DELETE');
  assert has_table_privilege('authenticated', 'public.agent_token_clients', 'SELECT'),
    'signed-in clients still list tokens through the view';
  assert not has_table_privilege('anon', 'public.agent_tokens', 'SELECT');
end $$;
rollback;
