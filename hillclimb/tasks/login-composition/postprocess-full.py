"""Collect one completed full execution, never retry tests.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import subprocess,json,datetime,gzip,hashlib
p=Path(__file__).parent
assert (p/'full-v2-process.json').exists(), 'Full suite must finish naturally before collection'
rows=[]
for name,args in [('collect.py',['full-v2']),('runtime.py',['full-v2']),('metrics.py',[]),('restoration.py',['full-v2']),('accept.py',[]),('identity.py',[])]:
 r=subprocess.run(['python3',str(p/name),*args],capture_output=True,text=True)
 rows.append(dict(script=name,arguments=args,exit=r.returncode,stdout=r.stdout,stderr=r.stderr))
 (p/'postprocess-results.json').write_text(json.dumps(rows,indent=2))
 print(name,r.returncode,flush=True)
 if r.returncode:break
for name in ['focused','corrected-focused','composition-measurement','full-v2']:
 d=Path('/tmp/hillclimb-login-U-'+name+'.xcresult')
 if d.exists():
  with gzip.open(p/(name+'-external-xcresult.json.gz'),'wt') as f:
   json.dump(dict(path=str(d),files=[dict(path=str(v),bytes=v.stat().st_size,sha256=hashlib.sha256(v.read_bytes()).hexdigest()) for v in d.rglob('*') if v.is_file()]),f)
# Host sleep/wake evidence is scoped by actual timestamps rather than omitted.
r=subprocess.run(['pmset','-g','log'],capture_output=True,text=True)
start=json.loads((p/'full-v2-process.json').read_text())['startedUTC']
first=datetime.datetime.fromisoformat(start).astimezone().strftime('%Y-%m-%d')
last=datetime.datetime.fromisoformat(json.loads((p/'full-v2-process.json').read_text())['finishedUTC']).astimezone().strftime('%Y-%m-%d')
lines=[line for line in r.stdout.splitlines() if (line.startswith(first) or line.startswith(last)) and any(word in line.lower() for word in ['sleep','wake','clamshell','darkwake'])]
with gzip.open(p/'sleep-wake-log.txt.gz','wt') as f:f.write('\n'.join(lines))
(p/'sleep-wake-scope.json').write_text(json.dumps(dict(command=['pmset','-g','log'],exit=r.returncode,fullStart=start,fullEnd=json.loads((p/'full-v2-process.json').read_text())['finishedUTC'],scope='Raw host history retained for explicit interval inspection; idle assertion does not prevent clamshell sleep'),indent=2))
