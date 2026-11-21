"""Accept only a complete unfiltered pass with retained named baseline methods.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,hashlib,subprocess
p=Path('hillclimb/tasks/login-focus-polish');bundle='/tmp/hillclimb-focus-PM-bounded-matrix-full.xcresult'
for kind in ['summary','tests','metrics']:
 command=['xcrun','xcresulttool','get','test-results',kind,'--path',bundle]
 if kind!='metrics':command+=['--format','json']
 data=subprocess.check_output(command,text=True);(p/f'bounded-matrix-full-{kind}.json').write_text(data)
summary=json.loads((p/'bounded-matrix-full-summary.json').read_text());assert (summary['totalTestCount'],summary['passedTests'],summary['failedTests'],summary['skippedTests'])==(325,325,0,0),summary

def cases(node):
 if isinstance(node,dict):
  if node.get('nodeType')=='Test Case':yield node
  for value in node.values():yield from cases(value)
 elif isinstance(node,list):
  for item in node:yield from cases(item)
current=list(cases(json.loads((p/'bounded-matrix-full-tests.json').read_text())));old=list(cases(json.loads(Path('hillclimb/tasks/login-composition/full-v2-tests.json').read_text())));ids={r['nodeIdentifierURL'] for r in current};oldids={r['nodeIdentifierURL'] for r in old};assert len(current)==len(ids)==325 and len(oldids)==317;assert oldids<=ids;assert all(r['result']=='Passed' for r in current)
unit=sum('/LazyMansRemindersTests/' in r['nodeIdentifierURL'] for r in current);ui=sum('/HillclimbUITests/' in r['nodeIdentifierURL'] for r in current);assert (unit,ui)==(263,62)
freeze=json.loads((p/'bounded-matrix-freeze.json').read_text());assert all(hashlib.sha256(Path(k).read_bytes()).hexdigest()==v for k,v in freeze['hashes'].items())
tracked=[];generated=[]
for name,h in freeze['hashes'].items():
 r=subprocess.run(['git','show',freeze['sourceSHA']+':'+name],capture_output=True)
 if r.returncode==0:assert hashlib.sha256(r.stdout).hexdigest()==h;tracked.append(name)
 else:generated.append(name)
assert len(tracked)==94 and len(generated)==2,(len(tracked),generated)
prior=json.loads(Path('hillclimb/tasks/login-composition/acceptance.json').read_text());proof=dict(status='passed',source_sha=freeze['sourceSHA'],sourceIdentity=freeze['sourceIdentity'],total=325,passed=325,failed=0,skipped=0,unit=263,ui=62,baseline317Retained=True,transitivelyRetainedBaselines=prior['baselines'],newIDs=sorted(ids-oldids),allNamedIDs=sorted(ids),trackedSourceInputs=tracked,generatedInputs=generated,runtimeWarnings=summary.get('runtimeWarnings'),historicalFailures='full-final-summary.json322/2;measured-heading-full-summary.json323/1;both remain failed',configuration='Original generatedxctestrun; unfiltered serial;diagnostics never;timeouts enabled240/300',visualAcceptance='No numeric UI acceptance; independent grading required')
(p/'acceptance.json').write_text(json.dumps(proof,indent=2)+'\n');print('325/325passed;263unit+62UI;all317 and historical baseline IDs retained;94tracked+2generated inputs exact')
