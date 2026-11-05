"""Fresh offline checks after an actual combined pass; no retries.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import subprocess,json,datetime,hashlib,os,re
p=Path(__file__).parent;t=Path('hillclimb/tasks/login-composition');freeze=json.loads((t/'freeze.json').read_text())
acceptance=json.loads((t/'acceptance.json').read_text())
assert acceptance['allNamedTestsPassed'] and acceptance['sourceIdentity']==freeze['sourceIdentity']
inputs=json.loads((t/'offline-inputs.json').read_text());inputs.update(freeze['hashes'])
checks=[('python-ios',['python3','-B','-m','unittest','discover','-s','scripts/tests','-p','test_ios*.py'],23),('deno',['deno','test','--cached-only','supabase/functions/_shared/live_activity_test.ts','supabase/functions/_shared/board_loader_test.ts','supabase/functions/_shared/device_delivery_test.ts'],52),('deno-overflow',['deno','test','--cached-only','hillclimb/tasks/activity-overflow/offline-apns_test.ts'],4)]
for name,cmd,count in checks:
 assert all(hashlib.sha256(Path(f).read_bytes()).hexdigest()==h for f,h in inputs.items())
 start=datetime.datetime.now(datetime.timezone.utc).isoformat();r=subprocess.run(cmd,capture_output=True,text=True,env=dict(os.environ,NO_COLOR='1'));text=r.stdout+r.stderr
 observed=int(re.search(r'Ran (\d+) tests',text)[1]) if name=='python-ios' and re.search(r'Ran (\d+) tests',text) else int(re.search(r'(\d+) passed',text)[1]) if re.search(r'(\d+) passed',text) else None
 result=dict(command=cmd,exit=r.returncode,expectedCount=count,observedCount=observed,startedUTC=start,endedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),stdout=r.stdout,stderr=r.stderr,sourceIdentity=freeze['sourceIdentity'],frozenInputsMatch=all(hashlib.sha256(Path(f).read_bytes()).hexdigest()==h for f,h in inputs.items()))
 (p/(name+'.json')).write_text(json.dumps(result,indent=2));print(name,r.returncode,observed,flush=True)
 assert r.returncode==0 and observed==count and result['frozenInputsMatch'],name
