"""Executed result and restoration proof. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,json,datetime,sys
p=pathlib.Path(__file__).parent;name=sys.argv[1];r='/tmp/hillclimb-round5-048fb58b-'+name+'.xcresult'
out=p/(name+'-settings');out.mkdir(exist_ok=True)
subprocess.run(['xcrun','xcresulttool','export','attachments','--path',r,'--output-path',str(out),'--test-id','AccessibilitySettingsUITests'],check=True)
for kind in ['metrics','activities']:
 if kind=='activities':continue
 result=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path',r],capture_output=True,text=True);(p/(name+'-'+kind+'.json')).write_text(result.stdout or result.stderr)
proc=json.loads((p/(name+'-process.json')).read_text());local=lambda v:datetime.datetime.fromisoformat(v).astimezone().strftime('%Y-%m-%d %H:%M:%S')
cmd=['xcrun','simctl','spawn','78F5A64F-7B2E-4562-8EF9-10F3312CC694','log','show','--start',local(proc['startedUTC']),'--end',local(proc['finishedUTC']),'--style','json','--predicate','process == "LazyMansReminders" AND (messageType == fault OR messageType == error OR eventMessage CONTAINS[c] "Invalid frame")']
res=subprocess.run(cmd,capture_output=True,text=True);res.check_returncode();(p/(name+'-runtime-log.json')).write_text(res.stdout);events=json.loads(res.stdout);s=json.loads((p/(name+'-summary.json')).read_text());(p/(name+'-runtime-summary.json')).write_text(json.dumps(dict(command=cmd,runtimeWarnings=s['runtimeWarnings'],invalidFrameEvents=sum('invalid frame' in e.get('eventMessage','').lower() for e in events),allErrorFaultEvents=len(events)),indent=2))
print(json.dumps(s,indent=2))
