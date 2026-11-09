"""Verify eight actual captures and subsequent edge taps in each completed matrix.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import json,pathlib,sys
p=pathlib.Path(__file__).parent;reports=[]
for mode in sys.argv[1:]:
 d=json.loads((p/(mode+'-activities.json')).read_text());titles=[]
 def walk(x):
  if isinstance(x,dict):
   if 'title'in x:titles.append(x['title'])
   for v in x.values():walk(v)
  elif isinstance(x,list):
   for v in x:walk(v)
 walk(d);captures=[(i,t) for i,t in enumerate(titles) if t.startswith("Added attachment named 'signin-")];assert len(captures)==8
 cases=[]
 for j,(i,t) in enumerate(captures):
  section=titles[i:captures[j+1][0] if j+1<len(captures) else len(titles)]
  done=[x for x in section if x=='Tap "Done" Button[0.95, 0.50]'];alternate=[x for x in section if x.startswith('Tap "Use ') and x.endswith('Button[0.05, 0.50]')];assert done and alternate
  cases.append({'capture':t,'doneEdgeTaps':done,'alternateEdgeTaps':alternate})
 summary=json.loads((p/(mode+'-summary.json')).read_text());assert summary['totalTestCount']>=1 and summary['failedTests']==0 and summary['skippedTests']==0
 reports.append({'run':mode,'cases':cases,'passed':summary['passedTests'],'runtimeWarnings':summary['runtimeWarnings']})
(p/'matrix-proof.json').write_text(json.dumps(reports,indent=2));print('Verified',len(reports),'runs;',8*len(reports),'complete capture/edge cases')
