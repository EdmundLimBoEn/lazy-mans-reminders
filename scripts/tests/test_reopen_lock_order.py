"""Run with PostgreSQL's bin directory on PATH; creates a disposable local cluster."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
OWNER = '00000000-0000-0000-0000-000000000001'
OTHER = '00000000-0000-0000-0000-000000000002'
REMINDER = '00000000-0000-0000-0000-000000000011'
ROUTINE = '00000000-0000-0000-0000-000000000021'


class ReopenLockOrderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for tool in ('initdb', 'pg_ctl', 'psql'):
            if not shutil.which(tool):
                raise RuntimeError(f'{tool} is required for the concurrent database regression')
        cls.temp = tempfile.TemporaryDirectory(prefix='lmr-reopen-')
        cls.data = cls.temp.name + '/data'
        cls.env = {**os.environ, 'PGHOST': cls.temp.name, 'PGPORT': '5432',
                   'PGDATABASE': 'postgres', 'PGUSER': 'postgres', 'PGPASSWORD': ''}
        subprocess.run(['initdb', '-D', cls.data, '-U', 'postgres', '-A', 'trust', '--no-locale'],
                       check=True, stdout=subprocess.DEVNULL)
        subprocess.run(['pg_ctl', '-D', cls.data, '-l', cls.temp.name + '/server.log',
                        '-o', f"-k {cls.temp.name} -c listen_addresses=''", '-w', 'start'],
                       check=True, stdout=subprocess.DEVNULL)
        cls.addClassCleanup(cls.cleanup)
        cls.sql("""
          create role anon; create role authenticated; create role service_role bypassrls;
          create schema auth; create table auth.users(id uuid primary key);
          create function auth.uid() returns uuid language sql stable as $$
            select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
          grant usage on schema auth to authenticated, service_role;
          create publication supabase_realtime;
        """)
        for name in ('202608060001_create_reminders.sql', '202608080001_completed_at_and_cleanup.sql',
                     '202610120001_routine_reminders.sql', '202610220001_routine_ownership_and_overflow.sql',
                     '202610220003_reminder_quotas.sql', '202610280002_reopen_reminder_lock_order.sql'):
            source = (ROOT / 'supabase/migrations' / name).read_text()
            # This isolated vanilla PostgreSQL cluster has no Supabase cron or crypto extensions.
            source = '\n'.join(line for line in source.splitlines()
                               if not line.startswith(('create extension', 'select cron.schedule')))
            cls.sql(source)
        cls.sql(f"""
          grant select, insert, update, delete on public.reminders to authenticated, service_role;
          insert into auth.users values ('{OWNER}'), ('{OTHER}');
          insert into public.routine_reminders(id,user_id,text,interval_days,start_date,local_time,timezone)
            values ('{ROUTINE}','{OWNER}','Routine',1,current_date,'09:00','UTC');
          update public.routine_reminders set next_run_at = now() - interval '1 minute';
          insert into public.reminders(id,user_id,text,is_done,routine_id)
            values ('{REMINDER}','{OWNER}','Completed',true,'{ROUTINE}');
          insert into public.reminders(id,user_id,text,is_done)
            values ('{OTHER}','{OTHER}','Other owner',true);
        """)

    @classmethod
    def cleanup(cls):
        subprocess.run(['pg_ctl', '-D', cls.data, '-m', 'immediate', '-w', 'stop'],
                       check=True, stdout=subprocess.DEVNULL)
        cls.temp.cleanup()

    @classmethod
    def process(cls):
        return subprocess.Popen(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], env=cls.env,
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True)

    @classmethod
    def sql(cls, statement):
        process = cls.process()
        out, err = process.communicate(statement, timeout=10)
        if process.returncode:
            raise AssertionError(err)
        return out.strip()

    def test_concurrent_scheduler_and_reopen(self):
        scheduler = self.process()
        reopen = None
        try:
            scheduler.stdin.write(f"begin; select pg_advisory_xact_lock(hashtextextended('{OWNER}',0));\n\\echo LOCKED\n")
            scheduler.stdin.flush()
            while scheduler.stdout.readline().strip() != 'LOCKED':
                self.assertIsNone(scheduler.poll())
            reopen = self.process()
            reopen.stdin.write(f"set application_name='reopen-regression'; set role authenticated; "
                               f"set request.jwt.claim.sub='{OWNER}'; "
                               f"select count(*) from public.reopen_reminder('{OWNER}','{REMINDER}');\n")
            reopen.stdin.flush()
            deadline = time.monotonic() + 5
            while self.sql("select count(*) from pg_stat_activity where application_name='reopen-regression' and wait_event='advisory'") != '1':
                self.assertLess(time.monotonic(), deadline, 'Reopen never waited on the owner lock')
                time.sleep(.02)
            # If reopening already holds the reminder row, the scheduler deadlocks here.
            out, err = scheduler.communicate('select public.fire_due_routines(); commit;\n', timeout=10)
            self.assertEqual(scheduler.returncode, 0, err)
            self.assertEqual(out.strip(), '1', err)
            out, err = reopen.communicate(timeout=10)
            self.assertEqual(reopen.returncode, 0, err)
            self.assertEqual(out.strip(), '1', err)
            self.assertEqual(self.sql(f"select not is_done and completed_at is null from reminders where id='{REMINDER}'"), 't')
        finally:
            for process in (scheduler, reopen):
                if process and process.poll() is None:
                    process.kill()
                    process.communicate()

    def test_ownership_permissions_and_quota(self):
        self.assertEqual(self.sql("select has_function_privilege('anon','public.reopen_reminder(uuid,uuid,text)','execute')"), 'f')
        for owner, reminder in ((OTHER, OTHER), (OWNER, OTHER)):
            self.assertEqual(self.sql(f"set role authenticated; set request.jwt.claim.sub='{OWNER}'; select count(*) from public.reopen_reminder('{owner}','{reminder}')"), '0')
        self.assertEqual(self.sql(f"set role service_role; select count(*) from public.reopen_reminder('{OTHER}','{REMINDER}')"), '0')
        self.assertEqual(self.sql(f"set role service_role; select text from public.reopen_reminder('{OWNER}','{REMINDER}','Edited')"), 'Edited')
        self.sql(f"update reminders set is_done=true where id='{REMINDER}'; insert into reminders(user_id,text) select '{OWNER}','Slot' from generate_series(1,16)")
        with self.assertRaisesRegex(AssertionError, 'at most 16 active reminders'):
            self.sql(f"set role authenticated; set request.jwt.claim.sub='{OWNER}'; select * from public.reopen_reminder('{OWNER}','{REMINDER}')")
        self.assertEqual(self.sql(f"select is_done from reminders where id='{REMINDER}'"), 't')


if __name__ == '__main__':
    unittest.main()
