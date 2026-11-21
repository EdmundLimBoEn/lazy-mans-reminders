import pathlib,json,hashlib
p=pathlib.Path(__file__).parent

def cases(file):
 result={}
 def visit(n):
  if n.get('nodeType')=='Test Case':result[n['nodeIdentifierURL']]=n['result']
  for c in n.get('children',[]):visit(c)
 for n in json.loads(file.read_text())['testNodes']:visit(n)
 return result
actual=cases(p/'full-tests.json'); old=cases(pathlib.Path('hillclimb/validation/round5/combined-tests.json')); older=cases(pathlib.Path('hillclimb/validation/round4/combined-tests.json'))
assert len(old)==293 and len(older)==285
assert older.keys()<=old.keys()<=actual.keys()
assert len(actual)==297 and all(v=='Passed' for v in actual.values())
s=json.loads((p/'full-summary.json').read_text());assert s['passedTests']==s['totalTestCount']==297 and s['failedTests']==s['skippedTests']==0
(p/'acceptance.json').write_text(json.dumps(dict(total=297,unit=263,ui=34,baseline293Retained=True,baseline285Retained=True,failures=0,skips=0,newTests=sorted(actual.keys()-old.keys())),indent=2))
print('297/297; all 293 and 285 baseline named IDs retained')
