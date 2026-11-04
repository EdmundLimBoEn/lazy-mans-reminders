"""Collect finished result only. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
import subprocess,json,sys,datetime,gzip,hashlib
p=Path(__file__).parent;name=sys.argv[1];result='/tmp/activity-tightening-'+name+'.xcresult'
for cls,folder in [('AccessibilitySettingsUITests',name+'-settings'),('ActivityLayoutTests',name+'-unit-renders'),('ActivityNativeLayoutTests',name+'-native-test')]:
 out=p/folder;out.mkdir(exist_ok=True);subprocess.run(['xcrun','xcresulttool','export','attachments','--path',result,'--output-path',str(out),'--test-id',cls],check=True)
r=json.loads((p/(name+'.json')).read_text());local=lambda v:datetime.datetime.fromisoformat(v).astimezone().strftime('%Y-%m-%d %H:%M:%S')
cmd=['xcrun','simctl','spawn','78F5A64F-7B2E-4562-8EF9-10F3312CC694','log','show','--start',local(r['startUTC']),'--end',local(r['endUTC']),'--style','json','--predicate','process == "LazyMansReminders" AND (messageType == fault OR messageType == error OR eventMessage CONTAINS[c] "Invalid frame")']
r=subprocess.run(cmd,capture_output=True,text=True);r.check_returncode();events=json.loads(r.stdout);f=p/(name+'-runtime-events.json.gz');f.write_bytes(gzip.compress(r.stdout.encode(),mtime=0));summary=json.loads((p/(name+'-summary.json')).read_text());(p/(name+'-runtime-summary.json')).write_text(json.dumps(dict(command=cmd,runtimeWarnings=summary['runtimeWarnings'],invalidFrameEvents=sum('invalid frame' in e.get('eventMessage','').lower() for e in events),allErrorFaultEvents=len(events),eventFile=str(f),sha256=hashlib.sha256(f.read_bytes()).hexdigest()),indent=2))
