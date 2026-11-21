"""Task-local runtime and native evidence inventory.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,subprocess,datetime,sys,collections
p=pathlib.Path(__file__).parent;name=sys.argv[1]
proc=json.loads((p/(name+'-process.json')).read_text())
def date(t):return datetime.datetime.fromtimestamp(t).strftime('%Y-%m-%d %H:%M:%S')
cmd=['xcrun','simctl','spawn','8E8380DE-364D-4899-99B8-D15ED0494FFD','log','show','--start',date(proc['start']),'--end',date(proc['start']+proc['elapsed']),'--style','json','--predicate','process == "LazyMansReminders" AND (messageType == fault OR messageType == error OR eventMessage CONTAINS[c] "Invalid frame")']
r=subprocess.run(cmd,capture_output=True,text=True);r.check_returncode();events=json.loads(r.stdout)
s=json.loads((p/(name+'-summary.json')).read_text())
(p/(name+'-runtime-summary.json')).write_text(json.dumps(dict(command=cmd,exit=r.returncode,stderr=r.stderr,runtimeWarnings=s['runtimeWarnings'],invalidFrameEvents=[e for e in events if 'invalid frame' in e.get('eventMessage','').lower()],errorFaultCount=len(events),messages=collections.Counter(e.get('eventMessage','') for e in events)),indent=2))
