"""Require original named tests and no skips. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,collections
p=pathlib.Path(__file__).parent

def cases(path):
 result={}
 def walk(n):
  if isinstance(n,dict):
   if n.get('nodeType')=='Test Case':result[n['nodeIdentifierURL']]=n['result']
   for c in n.get('children',[]):walk(c)
  elif isinstance(n,list):
   for c in n:walk(c)
 walk(json.loads(path.read_text())['testNodes']);return result
old=cases(p.parent/'activity-tightening/candidate-full-tests.json');new=cases(p/'full-tests.json')
assert len(old)==293,len(old)
assert old.keys()<=new.keys(),old.keys()-new.keys()
assert len(new)==296,len(new)
assert set(new.values())=={'Passed'},collections.Counter(new.values())
record=dict(baseline=293,total=296,unit=sum('/LazyMansRemindersTests/' in k for k in new),UI=sum('/HillclimbUITests/' in k for k in new),all293IDsRetained=True,results=dict(collections.Counter(new.values())),added=sorted(new.keys()-old.keys()))
(p/'acceptance.json').write_text(json.dumps(record,indent=2));print(json.dumps(record,indent=2))
