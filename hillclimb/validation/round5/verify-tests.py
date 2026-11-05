"""Authoritative named test count and baseline preservation.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json
p=pathlib.Path(__file__).parent

def cases(file):
 result={}
 def visit(n):
  if n.get('nodeType')=='Test Case':result[n['nodeIdentifierURL']]=n['result']
  for c in n.get('children',[]):visit(c)
 for n in json.loads(file.read_text())['testNodes']:visit(n)
 return result
actual=cases(p/'combined-tests.json');baseline=cases(pathlib.Path('hillclimb/validation/round4/combined-tests.json'))
assert len(baseline)==285 and baseline.keys()<=actual.keys()
assert len(actual)==293 and all(v=='Passed' for v in actual.values())
unit=[k for k in actual if '/LazyMansRemindersTests/' in k];ui=[k for k in actual if '/HillclimbUITests/' in k]
assert len(unit)==263 and len(ui)==30
s=json.loads((p/'combined-summary.json').read_text());assert s['totalTestCount']==s['passedTests']==293 and s['failedTests']==s['skippedTests']==0
(p/'test-acceptance.json').write_text(json.dumps(dict(tests=len(actual),unit=len(unit),ui=len(ui),baselineRetained=len(baseline),allNamedTestsPassed=True,failed=0,skipped=0),indent=2))
print('293 passed;263 unit+30 UI;all285 original IDs retained')
