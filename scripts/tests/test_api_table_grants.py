"""Exercise API roles and analytics rollout on disposable PostgreSQL databases."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / 'supabase' / 'migrations'
OWNER = '00000000-0000-0000-0000-000000000001'
OTHER = '00000000-0000-0000-0000-000000000002'


class _DisposableDatabase(unittest.TestCase):
    stop_after = None

    @classmethod
    def setUpClass(cls):
        for tool in ('initdb', 'postgres'):
            if shutil.which(tool) is None:
                raise unittest.SkipTest(f'{tool} is required for the API table grants regression')
        temp = tempfile.TemporaryDirectory(prefix='lmr-api-grants-')
        cls.addClassCleanup(temp.cleanup)
        cls.data = Path(temp.name) / 'data'
        subprocess.run(
            ['initdb', '-D', cls.data, '-U', 'postgres', '-A', 'trust', '--no-locale'],
            check=True, stdout=subprocess.DEVNULL, timeout=30,
        )
        # Provide the Supabase schemas needed by the migrations. Cron jobs are
        # inert and Vault is empty so writes cannot cause an outbound request.
        cls.sql(f"""
          -- A standalone backend can allocate OIDs in the reserved range.
          -- RLS applies only to relations with normal OIDs (16384 or higher).
          do $$ begin
            while pg_nextoid('pg_class', 'oid', 'pg_class_oid_index') < 16384 loop
            end loop;
          end $$;
          create role anon;
          create role authenticated;
          create role service_role bypassrls;
          create schema auth;
          create table auth.users (id uuid primary key);
          create table auth.sessions (id uuid primary key, user_id uuid, not_after timestamptz);
          create function auth.jwt() returns jsonb language sql stable as $$
            select nullif(current_setting('request.jwt.claims', true), '')::jsonb
          $$;
          create function auth.uid() returns uuid language sql stable as $$
            select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                            auth.jwt()->>'sub')::uuid
          $$;
          grant usage on schema auth to authenticated, service_role;
          insert into auth.users values ('{OWNER}'), ('{OTHER}');
          create publication supabase_realtime;
          create schema extensions;
          create extension pgcrypto with schema extensions;
          create schema vault;
          create table vault.decrypted_secrets (name text, decrypted_secret text);
          create schema cron;
          create table cron.job (jobid bigint, jobname text);
          create function cron.schedule(text, text, text) returns bigint
            language sql as $$ select 1::bigint $$;
          create function cron.unschedule(bigint) returns boolean
            language sql as $$ select true $$;
        """)
        for migration in sorted(MIGRATIONS.glob('*.sql')):
            sql = re.sub(r'^create extension if not exists pg_(cron|net)\b[^\n]*\n',
                         '', migration.read_text(), flags=re.MULTILINE)
            cls.sql(sql, migration.name)
            if migration.name == cls.stop_after:
                break

    @classmethod
    def sql(cls, statement, source='API role operation'):
        # The single-user backend runs locally without opening any sockets.
        # With -j, only a semicolon followed by two newlines ends the batch.
        batch = '\n'.join(line or ' ' for line in statement.strip().splitlines())
        result = subprocess.run(
            ['postgres', '--single', '-j', '-D', cls.data, '-c', 'lc_messages=C',
             '-c', 'log_min_error_statement=panic', 'postgres'],
            input=batch + '\n\n', text=True, capture_output=True, timeout=30,
        )
        if result.returncode or re.search(r'\b(?:ERROR|FATAL|PANIC):', result.stderr):
            raise AssertionError(f'{source}\n{result.stderr}')


class AnalyticsRolloutTests(_DisposableDatabase):
    stop_after = '20261113000200_usage_events.sql'

    def test_sql_editor_rollout_counts_an_edit(self):
        runbook = (ROOT / 'docs/analytics/enable.md').read_text()
        before_deploy = runbook.split('## Live enablement\n', 1)[1].split('npm run deploy', 1)[0]
        # Use the SQL Editor override for the flag, then apply the migration files
        # the runbook requires between that override and the Worker deployment.
        toggle, prerequisites = before_deploy.split('```sql\n', 1)[1].split('```', 1)
        self.sql(toggle, 'Runbook SQL Editor enablement')
        for path in re.findall(r'`(supabase/migrations/[^`]+\.sql)`', prerequisites):
            self.sql((ROOT / path).read_text(), path)

        self.sql(f"""
          begin;
          insert into public.reminders (id, user_id, text) values ('{OWNER}', '{OWNER}', 'Before edit');
          grant select, update (text) on public.reminders to service_role;
          set local role service_role;
          do $$
          declare today date := (statement_timestamp() at time zone 'UTC')::date;
          begin
            begin
              -- The Worker treats an analytics error as best effort and still edits.
              perform public.record_agent_usage('{OWNER}', 'mcp_edit');
            exception when invalid_parameter_value or check_violation then null;
            end;
            update public.reminders set text = 'After edit' where id = '{OWNER}' and user_id = '{OWNER}';
            assert found, 'Fixture reminder edit did not succeed';
            assert coalesce((select events from public.usage_source_report(today, today)
              where source = 'agent' and event = 'mcp_edit'), 0) = 1,
              'One successful edit must increment mcp_edit by one';
          end $$;
          rollback;
        """, 'Rollout edit verification')


class ApiTableGrantsTests(_DisposableDatabase):
    def test_reminder_crud_and_service_reopen(self):
        self.sql(f"""
          begin;
          insert into public.reminders(user_id, text, is_done, completed_at)
            values ('{OTHER}', 'Private', true, now() - interval '4 days');
          set local role authenticated;
          set local request.jwt.claim.sub = '{OWNER}';
          do $$
          declare reminder_id uuid;
          begin
            insert into public.reminders (user_id, text, sort_order)
              values (auth.uid(), 'New reminder', 0) returning id into reminder_id;
            assert (select count(*) from public.reminders) = 1;
            update public.reminders set is_done = true where id = reminder_id;
            assert (select is_done from public.reminders where id = reminder_id);
          end $$;
          set local role service_role;
          do $$ begin
            assert (select count(*) from public.reminders) = 2;
            assert (select not is_done and text = 'Edited'
                    from public.reopen_reminder('{OWNER}',
                      (select id from public.reminders where user_id = '{OWNER}'), 'Edited'));
          end $$;
          set local role authenticated;
          delete from public.reminders;
          do $$ begin
            assert (select count(*) from public.reminders) = 0;
          end $$;
          set local role service_role;
          do $$ begin
            assert (select count(*) from public.reminders) = 1;
            assert public.delete_old_completed_reminders() = 1;
          end $$;
          rollback;
        """)

    def test_device_registration_and_service_delivery(self):
        self.sql(f"""
          begin;
          insert into public.device_tokens(token, user_id) values (repeat('b', 64), '{OTHER}');
          set local role authenticated;
          set local request.jwt.claim.sub = '{OWNER}';
          insert into public.device_tokens(token, user_id, environment, push_to_start_token)
            values (repeat('a', 64), auth.uid(), 'development', repeat('c', 64));
          insert into public.device_tokens(token, user_id, environment, push_to_start_token)
            values (repeat('a', 64), auth.uid(), 'production', repeat('d', 64))
            on conflict (token) do update set user_id = excluded.user_id,
              environment = excluded.environment, push_to_start_token = excluded.push_to_start_token;
          do $$ begin
            assert (select environment from public.device_tokens) = 'production';
          end $$;
          set local role service_role;
          do $$ begin
            assert public.claim_device_delivery(repeat('a', 64), '{OWNER}', gen_random_uuid());
            perform public.record_live_activity_start(
              repeat('a', 64), '{OWNER}', repeat('e', 64), now(), true);
            update public.device_tokens set push_to_start_token = null
              where token = repeat('a', 64) and user_id = '{OWNER}';
            assert (select push_to_start_token is null and activity_started_at = now()
                      and retiring_activity_push_token = repeat('e', 64) from public.device_tokens
                    where token = repeat('a', 64));
          end $$;
          delete from public.device_tokens where token = repeat('b', 64);
          set local role authenticated;
          delete from public.device_tokens where token = repeat('a', 64);
          set local role service_role;
          do $$ begin
            assert (select count(*) from public.device_tokens) = 0;
          end $$;
          rollback;
        """)

    def test_preference_sync_and_board_reads(self):
        self.sql(f"""
          begin;
          insert into public.lock_screen_prefs(user_id, max_lines) values ('{OTHER}', 9);
          set local role authenticated;
          set local request.jwt.claim.sub = '{OWNER}';
          insert into public.lock_screen_prefs (user_id, max_lines, point_size)
            values (auth.uid(), 5, 15);
          insert into public.lock_screen_prefs (user_id, max_lines, point_size)
            values (auth.uid(), 7, 17)
            on conflict (user_id) do update set user_id = excluded.user_id,
              max_lines = excluded.max_lines, point_size = excluded.point_size;
          do $$ begin
            assert (select max_lines from public.lock_screen_prefs) = 7;
          end $$;
          set local role service_role;
          do $$ begin
            assert (select max_lines from public.lock_screen_prefs where user_id = '{OTHER}') = 9;
          end $$;
          rollback;
        """)

    def test_routine_create_retry_at_quota_returns_same_schedule_and_fires_once(self):
        owner = '00000000-0000-0000-0000-000000000003'
        routine_id = '10000000-0000-0000-0000-000000000001'
        self.addCleanup(self.sql, f"delete from auth.users where id = '{owner}';")
        self.sql(f"""
          begin;
          insert into auth.users values ('{owner}');
          insert into public.routine_reminders(user_id, text, interval_days, start_date, local_time, timezone, enabled)
            select '{owner}', 'Paused', 7, current_date, '19:00', 'UTC', false
            from generate_series(1, 49);
          set local role authenticated;
          set local request.jwt.claim.sub = '{owner}';
          select public.create_routine_reminder('{routine_id}', '{owner}', 'Uniform', 7, current_date, '19:00', 'UTC');
          reset role;
          update public.routine_reminders set next_run_at = now() - interval '1 minute'
            where id = '{routine_id}';
          commit;
        """)
        self.sql(f"""
          begin;
          set local role authenticated;
          set local request.jwt.claim.sub = '{owner}';
          do $$ begin
            assert public.create_routine_reminder(
              '{routine_id}', '{owner}', 'Uniform', 7, current_date, '19:00', 'UTC'
            ) = '{routine_id}'::uuid, 'Retry must return the original routine even at quota';
            assert (select count(*) from public.routine_reminders where text = 'Uniform') = 1;
          end $$;
          set local request.jwt.claim.sub = '{OTHER}';
          do $$ begin
            begin
              perform public.create_routine_reminder(
                '{routine_id}', '{owner}', 'Uniform', 7, current_date, '19:00', 'UTC');
              assert false, 'Retry accepted a different owner';
            exception when insufficient_privilege then null;
            end;
            begin
              perform public.create_routine_reminder(
                '{routine_id}', '{OTHER}', 'Uniform', 7, current_date, '19:00', 'UTC');
              assert false, 'A foreign routine ID was returned as a successful create';
            exception when unique_violation then null;
            end;
          end $$;
          reset role;
          do $$ begin
            assert public.fire_due_routines() = 1, 'The original due occurrence must fire once';
            assert public.fire_due_routines() = 0;
            assert (select count(*) from public.reminders where user_id = '{owner}' and text = 'Uniform') = 1;
          end $$;
          rollback;
        """)

    def test_personal_token_mint_requires_live_owner_session(self):
        revoked = '10000000-0000-0000-0000-000000000001'
        live = '10000000-0000-0000-0000-000000000002'
        foreign = '10000000-0000-0000-0000-000000000003'
        expired = '10000000-0000-0000-0000-000000000004'
        self.sql(f"""
          begin;
          insert into auth.sessions (id, user_id, not_after) values
            ('{revoked}', '{OWNER}', null), ('{live}', '{OWNER}', null),
            ('{foreign}', '{OTHER}', null), ('{expired}', '{OWNER}', now() - interval '1 hour');
          delete from auth.sessions where id = '{revoked}';
          set local role authenticated;
          do $$
          declare
            claims jsonb := jsonb_build_object('sub', '{OWNER}', 'role', 'authenticated',
                                               'exp', extract(epoch from now() + interval '1 hour'));
            session_id text;
          begin
            foreach session_id in array array['{revoked}', '{foreign}', '{expired}', null] loop
              perform set_config('request.jwt.claims', jsonb_strip_nulls(
                claims || jsonb_build_object('session_id', session_id))::text, true);
              begin
                perform public.mint_agent_token('Denied');
                assert false, 'Mint accepted an inactive or unowned session';
              exception when raise_exception then
                if sqlerrm <> 'Not authenticated' then raise; end if;
              end;
            end loop;
            assert (select count(*) = 0 from public.agent_tokens);
            perform set_config('request.jwt.claims',
              (claims || jsonb_build_object('session_id', '{live}'))::text, true);
            perform public.mint_agent_token('Allowed');
            assert (select count(*) = 1 from public.agent_tokens
                    where user_id = '{OWNER}' and name = 'Allowed');
          end $$;
          rollback;
        """)

    def test_personal_token_lookup_and_last_used(self):
        self.sql(f"""
          begin;
          insert into public.agent_tokens (id, user_id, name, token_hash)
            values ('{OWNER}', '{OWNER}', 'Personal token', 'fixture-hash'),
                   ('{OTHER}', '{OTHER}', 'Other token', 'other-fixture-hash');
          set local role service_role;
          do $$ declare token record; begin
            select id, user_id, name, token_hash, revoked_at into strict token
              from public.agent_tokens where id = '{OWNER}';
            assert token.token_hash = 'fixture-hash' and token.revoked_at is null;
            update public.agent_tokens set last_used_at = now() where id = token.id;
          end $$;
          set local role authenticated;
          set local request.jwt.claim.sub = '{OWNER}';
          do $$ begin
            assert (select last_used_at = now() from public.agent_token_clients);
            assert not has_column_privilege('public.agent_tokens', 'token_hash', 'SELECT');
          end $$;
          rollback;
        """)
