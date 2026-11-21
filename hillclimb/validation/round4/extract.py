"""Retain structured runtime issues and scoped simulator logs.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import subprocess,json,pathlib,datetime
p=pathlib.Path(__file__).parent;result='/tmp/notepad-round4-original17-combined.xcresult'
for name in ['testFocusedEmailAndPasswordClearKeyboardInBothAppearances','testDemoBlocksExternalActionsAndAllowsLocalRecovery']:
 cmd=['xcrun','xcresulttool','get','test-results','test-details','--path',result,'--test-id','SignInSurfaceUITests/'+name+'()'];r=subprocess.run(cmd,capture_output=True,text=True);(p/(name+'.json')).write_text(r.stdout or r.stderr)
r=subprocess.run(['xcrun','xcresulttool','get','object','--legacy','--format','json','--path',result],capture_output=True,text=True)
obj=json.loads(r.stdout);(p/'xcresult-issues.json').write_text(json.dumps(obj.get('issues',{}),indent=2))
start=json.loads((p/'test-process.json').read_text())['startedUTC'];dt=datetime.datetime.fromisoformat(start).astimezone().strftime('%Y-%m-%d %H:%M:%S')
cmd=['xcrun','simctl','spawn','78F5A64F-7B2E-4562-8EF9-10F3312CC694','log','show','--start',dt,'--style','json','--predicate','process == "LazyMansReminders" AND (messageType == fault OR messageType == error OR eventMessage CONTAINS[c] "Invalid frame")']
r=subprocess.run(cmd,capture_output=True,text=True);(p/'scoped-unified-log.json').write_text(json.dumps({'command':cmd,'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr},indent=2))
