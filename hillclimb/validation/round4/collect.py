"""Collect full-suite diagnostics without suppressing unrelated faults.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,subprocess,json,datetime
P=pathlib.Path(__file__).parent;R='/tmp/notepad-round4-original17-combined.xcresult'
def collect(name,cmd):
 r=subprocess.run(cmd,capture_output=True,text=True);(P/name).write_text(r.stdout if r.returncode==0 else json.dumps(dict(command=cmd,exit=r.returncode,stdout=r.stdout,stderr=r.stderr),indent=2));r.check_returncode();return json.loads(r.stdout)
for kind in ['metrics','insights']:
 collect('combined-'+kind+'.json',['xcrun','xcresulttool','get','test-results',kind,'--path',R])
collect('combined-activities.json',['xcrun','xcresulttool','get','test-results','activities','--path',R,'--test-id','SignInSurfaceUITests/testFocusedEmailAndPasswordClearKeyboardInBothAppearances()'])
obj=collect('combined-object.json',['xcrun','xcresulttool','get','object','--legacy','--format','json','--path',R]);(P/'xcresult-issues.json').write_text(json.dumps(obj.get('issues',{}),indent=2))
s=json.loads((P/'combined-summary.json').read_text());start=json.loads((P/'test-process.json').read_text())['startedUTC'];end=datetime.datetime.fromtimestamp(s['finishTime'],datetime.timezone.utc).isoformat()
local=lambda t:datetime.datetime.fromisoformat(t).astimezone().strftime('%Y-%m-%d %H:%M:%S')
cmd=['xcrun','simctl','spawn','78F5A64F-7B2E-4562-8EF9-10F3312CC694','log','show','--start',local(start),'--end',local(end),'--style','json','--predicate','process == "LazyMansReminders" AND (messageType == fault OR messageType == error OR eventMessage CONTAINS[c] "Invalid frame")']
r=subprocess.run(cmd,capture_output=True,text=True);(P/'scoped-unified-log.json').write_text(json.dumps(dict(command=cmd,exit=r.returncode,startUTC=start,endUTC=end,stdout=r.stdout,stderr=r.stderr),indent=2));r.check_returncode();events=json.loads(r.stdout);invalid=[e for e in events if 'invalid frame' in e.get('eventMessage','').lower()]
(P/'runtime-summary.json').write_text(json.dumps(dict(runtimeWarnings=s['runtimeWarnings'],invalidFrameEvents=len(invalid),otherErrorFaultEvents=len(events)-len(invalid),scopedStartUTC=start,scopedEndUTC=end),indent=2))
out=P/'rendered-unit';subprocess.run(['xcrun','xcresulttool','export','attachments','--path',R,'--output-path',str(out),'--test-id','ActivityLayoutTests/testRenderedLastLineFitsBothNativeSurfaceBudgets()'],check=True)
print(s['passedTests'],s['failedTests'],s['skippedTests'],'invalid-frame',len(invalid))
