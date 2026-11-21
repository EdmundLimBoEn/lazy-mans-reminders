"""Actual named retention; full packet acceptance is a separate gate.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,hashlib
p=Path(__file__).parent

def cases(path):
 result={}
 def walk(n):
  if isinstance(n,dict):
   if n.get('nodeType')=='Test Case':result[n['nodeIdentifierURL']]=n['result']
   for v in n.values():walk(v)
  elif isinstance(n,list):
   for v in n:walk(v)
 walk(json.loads(Path(path).read_text()))
 return result
ids=cases(p/'full-v2-tests.json');baselines={}
for count,file in [(308,'hillclimb/validation/round6/recheck/combined-tests.json'),(307,'hillclimb/validation/round6/combined-tests.json'),(293,'hillclimb/validation/round5/combined-tests.json')]:
 old=cases(file);assert len(old)==count
 baselines[count]=dict(path=file,sha256=hashlib.sha256(Path(file).read_bytes()).hexdigest(),retained=len(old.keys() & ids.keys()),missing=sorted(old.keys()-ids.keys()))
f=Path('hillclimb/validation/round6/baseline-304.json');old=set(json.loads(f.read_text()));assert len(old)==304
baselines[304]=dict(path=str(f),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),retained=len(old&ids.keys()),missing=sorted(old-ids.keys()))
summary=json.loads((p/'full-v2-summary.json').read_text());unit=sum('/LazyMansRemindersTests/' in k for k in ids);ui=sum('/HillclimbUITests/' in k for k in ids)
passed=sum(v=='Passed' for v in ids.values());failed=sum(v=='Failed' for v in ids.values());skipped=sum(v=='Skipped' for v in ids.values())
allPassed=len(ids)==317 and unit==263 and ui==54 and all(v=='Passed' for v in ids.values()) and summary['totalTestCount']==317 and summary['failedTests']==summary['skippedTests']==0 and all(not b['missing'] for b in baselines.values())
(p/'acceptance.json').write_text(json.dumps(dict(total=len(ids),unit=unit,ui=ui,baselines=baselines,passed=passed,failed=failed,skipped=skipped,allNamedTestsPassed=allPassed,allGatesPassed=False,validationPending=True,sourceFreeze='freeze.json',sourceIdentity=json.loads((p/'freeze.json').read_text())['sourceIdentity'],namedIDs=ids),indent=2))
print(dict(total=len(ids),unit=unit,ui=ui,allNamedTestsPassed=allPassed,failed=failed,skipped=skipped))
