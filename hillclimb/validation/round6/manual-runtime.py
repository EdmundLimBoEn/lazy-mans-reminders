"""Scoped native capture diagnostics, preserving error counts without raw duplicate logs.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,datetime,subprocess,gzip,hashlib
p=pathlib.Path(__file__).parent;times=[]
def scan(v):
 if isinstance(v,dict):
  for k,x in v.items():
   if k in ['startedUTC','endedUTC','started','utc'] and isinstance(x,str):
    try:times.append(datetime.datetime.fromisoformat(x))
    except ValueError:pass
   else:scan(x)
 elif isinstance(v,list):
  for x in v:scan(x)
for f in [*p.glob('capture-*.json'),p/'manual-operations.json']:scan(json.loads(f.read_text()))
local=lambda t:t.astimezone().strftime('%Y-%m-%d %H:%M:%S')
cmd=['xcrun','simctl','spawn','78F5A64F-7B2E-4562-8EF9-10F3312CC694','log','show','--start',local(min(times)),'--end',local(max(times)),'--style','json','--predicate','(process == "LazyMansReminders" OR process == "ReminderWidgetExtension") AND (messageType == fault OR messageType == error OR eventMessage CONTAINS[c] "Invalid frame")']
r=subprocess.run(cmd,capture_output=True);r.check_returncode();events=json.loads(r.stdout);out=p/'capture-runtime-log.json.gz';out.write_bytes(gzip.compress(r.stdout,mtime=0));summary=dict(command=cmd,start=min(times).isoformat(),end=max(times).isoformat(),errorFaultEvents=len(events),invalidFrameEvents=sum('invalid frame' in e.get('eventMessage','').lower() for e in events),byProcess={},rawSHA256=hashlib.sha256(r.stdout).hexdigest(),gzipFile=out.name,stderr=r.stderr.decode())
for e in events:summary['byProcess'][e.get('processImagePath','unknown').split('/')[-1]]=summary['byProcess'].get(e.get('processImagePath','unknown').split('/')[-1],0)+1
(p/'capture-runtime-summary.json').write_text(json.dumps(summary,indent=2));print(summary)
