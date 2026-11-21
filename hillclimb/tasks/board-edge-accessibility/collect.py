"""Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,json,datetime
p=pathlib.Path(__file__).parent;r='/tmp/notepad-board-edge-L-final.xcresult'
def collect(name,cmd):
 x=subprocess.run(cmd,capture_output=True,text=True);(p/name).write_text(x.stdout if x.returncode==0 else json.dumps(dict(command=cmd,exit=x.returncode,stdout=x.stdout,stderr=x.stderr),indent=2));x.check_returncode();return json.loads(x.stdout)
obj=collect('xcresult-object.json',['xcrun','xcresulttool','get','object','--legacy','--format','json','--path',r]);(p/'xcresult-issues.json').write_text(json.dumps(obj.get('issues',{}),indent=2))
s=json.loads((p/'combined-summary.json').read_text());start=json.loads((p/'test-process.json').read_text())['startedUTC'];end=datetime.datetime.fromtimestamp(s['finishTime'],datetime.timezone.utc).isoformat()
local=lambda t:datetime.datetime.fromisoformat(t).astimezone().strftime('%Y-%m-%d %H:%M:%S')
cmd=['xcrun','simctl','spawn','066ECE57-46B4-414A-B53E-523775329360','log','show','--start',local(start),'--end',local(end),'--style','json','--predicate','process == "LazyMansReminders" AND (messageType == fault OR messageType == error OR eventMessage CONTAINS[c] "Invalid frame")']
x=subprocess.run(cmd,capture_output=True,text=True);(p/'scoped-unified-log.json').write_text(json.dumps(dict(command=cmd,exit=x.returncode,stdout=x.stdout,stderr=x.stderr),indent=2));x.check_returncode();events=json.loads(x.stdout);invalid=[e for e in events if 'invalid frame' in e.get('eventMessage','').lower()]
(p/'runtime-summary.json').write_text(json.dumps(dict(runtimeWarnings=s['runtimeWarnings'],invalidFrameEvents=len(invalid),otherErrorFaultEvents=len(events)-len(invalid),scopedStartUTC=start,scopedEndUTC=end),indent=2))
for test in ['BoardEdgeAccessibilityUITests','BoardMultilineUITests','HillclimbUITests']:
 subprocess.run(['xcrun','xcresulttool','export','attachments','--path',r,'--output-path',str(p/('native-xctest-'+test)),'--test-id',test],check=True)
