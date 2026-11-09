"""Retain actual result activities, runtime issues and time-scoped logs.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,subprocess,json,datetime,sys
p=pathlib.Path(__file__).parent;mode=sys.argv[1];result='/tmp/notepad-signin-native-90ae0aca-'+mode+'.xcresult'
def collect(name,cmd):
 r=subprocess.run(cmd,capture_output=True,text=True);(p/name).write_text(r.stdout if r.returncode==0 else json.dumps({'command':cmd,'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr},indent=2));r.check_returncode();return json.loads(r.stdout)
activities=collect(mode+'-activities.json',['xcrun','xcresulttool','get','test-results','activities','--path',result,'--test-id','SignInSurfaceUITests/testFocusedEmailAndPasswordClearKeyboardInBothAppearances()'])
obj=collect(mode+'-object.json',['xcrun','xcresulttool','get','object','--legacy','--format','json','--path',result])
start=json.loads((p/(mode+'-process.json')).read_text())['startedUTC'];end=json.loads((p/(mode+'-process.json')).read_text()).get('endedUTC',datetime.datetime.fromtimestamp(json.loads((p/(mode+'-summary.json')).read_text())['finishTime'],datetime.timezone.utc).isoformat())
local=lambda t:datetime.datetime.fromisoformat(t).astimezone().strftime('%Y-%m-%d %H:%M:%S')
cmd=['xcrun','simctl','spawn','8E8380DE-364D-4899-99B8-D15ED0494FFD','log','show','--start',local(start),'--end',local(end),'--style','json','--predicate','process == "LazyMansReminders" AND (messageType == fault OR messageType == error OR eventMessage CONTAINS[c] "Invalid frame")']
r=subprocess.run(cmd,capture_output=True,text=True);(p/(mode+'-unified-log.json')).write_text(json.dumps({'command':cmd,'exit':r.returncode,'startUTC':start,'endUTC':end,'stdout':r.stdout,'stderr':r.stderr},indent=2));r.check_returncode()
events=json.loads(r.stdout);invalid=[e for e in events if 'invalid frame' in e.get('eventMessage','').lower()]
issues=obj.get('issues',{});(p/(mode+'-issues.json')).write_text(json.dumps(issues,indent=2))
summary={'runtimeWarnings':json.loads((p/(mode+'-summary.json')).read_text())['runtimeWarnings'],'invalidFrameEvents':len(invalid),'otherErrorFaultEvents':len(events)-len(invalid),'logExit':r.returncode,'scopedStartUTC':start,'scopedEndUTC':end}
(p/(mode+'-runtime-summary.json')).write_text(json.dumps(summary,indent=2));print(summary)
