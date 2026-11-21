"""Retain native attachments and diagnostics. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,json,hashlib,sys,datetime
p=pathlib.Path(__file__).parent; name=sys.argv[1]; result='/tmp/hillclimb-K-'+name+'.xcresult'
def get(kind):
 r=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path',result],capture_output=True,text=True);r.check_returncode();(p/(name+'-'+kind+'.json')).write_text(r.stdout);return json.loads(r.stdout)
s=get('summary');get('insights')
for cls in ['ErrorContrastUITests','AccessibilitySettingsUITests','SignInSurfaceUITests']:
 if cls not in (p/(name+'-tests.json')).read_text(): continue
 out=p/(name+'-'+cls)
 if not (out/'manifest.json').exists(): subprocess.run(['xcrun','xcresulttool','export','attachments','--path',result,'--output-path',str(out),'--test-id',cls],check=True,stdout=subprocess.DEVNULL)
 if (out/'manifest.json').exists():
  for t in json.loads((out/'manifest.json').read_text()):
   test=t['testIdentifier']
   subprocess.run(['xcrun','xcresulttool','get','test-results','activities','--path',result,'--test-id',test],stdout=(out/(test.split('/')[-1].replace('()','')+'-operations.json')).open('w'),check=True)
proc=json.loads((p/(name+'-process.json')).read_text())
local=lambda v:datetime.datetime.fromisoformat(v).astimezone().strftime('%Y-%m-%d %H:%M:%S')
cmd=['xcrun','simctl','spawn','8E8380DE-364D-4899-99B8-D15ED0494FFD','log','show','--start',local(proc['startedUTC']),'--end',local(proc['finishedUTC']),'--style','json','--predicate','process == "LazyMansReminders" AND (messageType == fault OR messageType == error OR eventMessage CONTAINS[c] "Invalid frame")']
r=subprocess.run(cmd,capture_output=True,text=True);r.check_returncode();(p/(name+'-runtime-log.json')).write_text(r.stdout); events=json.loads(r.stdout)
(p/(name+'-runtime-summary.json')).write_text(json.dumps(dict(runtimeWarnings=s['runtimeWarnings'],invalidFrameEvents=sum('invalid frame' in e.get('eventMessage','').lower() for e in events),allErrorFaultEvents=len(events),command=cmd),indent=2))
print(s)
