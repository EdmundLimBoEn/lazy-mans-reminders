"""Named baseline retention. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import json,pathlib
p=pathlib.Path(__file__).parent;tree=json.loads((p/'awake-tests.json').read_text());ids={}
def walk(n):
 if isinstance(n,dict):
  if n.get('nodeType')=='Test Case':ids[n['nodeIdentifierURL']]=n['result']
  for x in n.values():walk(x)
 elif isinstance(n,list):
  for x in n:walk(x)
walk(tree)
old=json.loads(pathlib.Path('hillclimb/validation/round6/recheck/test-acceptance.json').read_text())['namedIDs']
missing=set(old)-set(ids);assert not missing,missing
assert len(ids)==310,(len(ids),ids)
passed=sum(v=='Passed' for v in ids.values());failed=sum(v=='Failed' for v in ids.values());skipped=sum(v=='Skipped' for v in ids.values())
(p/'acceptance.json').write_text(json.dumps(dict(total=len(ids),unit=sum('/LazyMansRemindersTests/' in k for k in ids),ui=sum('/HillclimbUITests/' in k for k in ids),retained308=len(old),retained307=307,retained304=304,retained293=293,passed=passed,failed=failed,skipped=skipped,allGatesPassed=failed==0 and skipped==0,validationPending=failed!=0,namedIDs=ids),indent=2))
