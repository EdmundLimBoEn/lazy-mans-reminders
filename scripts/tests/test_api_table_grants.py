"""Exercise API roles without default table grants, with PostgreSQL binaries on PATH."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


MIGRATIONS = Path(__file__).resolve().parents[2] / 'supabase' / 'migrations'
OWNER = '00000000-0000-0000-0000-000000000001'
OTHER = '00000000-0000-0000-0000-000000000002'


class ApiTableGrantsTests(unittest.TestCase):
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
          create function auth.uid() returns uuid language sql stable as $$
            select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
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
