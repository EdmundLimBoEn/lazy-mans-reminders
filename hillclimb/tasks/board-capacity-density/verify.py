"""Named retention and immutable source verification.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,hashlib,subprocess,re,collections
p=pathlib.Path(__file__).parent

def cases(file):
 result={}
 def visit(n):
  if n.get('nodeType')=='Test Case':result[n['nodeIdentifierURL']]=n['result']
  for c in n.get('children',[]):visit(c)
 for n in json.loads(file.read_text())['testNodes']:visit(n)
 return result
actual=cases(p/'final-tests.json');baselines={}
for count,file in [(308,'hillclimb/validation/round6/recheck/combined-tests.json'),(307,'hillclimb/validation/round6/combined-tests.json'),(293,'hillclimb/validation/round5/combined-tests.json')]:
 f=pathlib.Path(file)
 base=cases(f);assert len(base)==count;baselines[count]=dict(file=file,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),retained=len(base.keys() & actual.keys()),missing=sorted(base.keys()-actual.keys()))
base304=pathlib.Path('hillclimb/validation/round6/baseline-304.json'); ids=json.loads(base304.read_text());assert len(ids)==304;baselines[304]=dict(file=str(base304),sha256=hashlib.sha256(base304.read_bytes()).hexdigest(),retained=len(set(ids)&actual.keys()),missing=sorted(set(ids)-actual.keys()))
allPassed=len(actual)==312 and all(v=='Passed' for v in actual.values())
unit=sum('/LazyMansRemindersTests/' in k for k in actual);ui=sum('/HillclimbUITests/' in k for k in actual)
s=json.loads((p/'final-summary.json').read_text())
baseline=json.loads((p/'baseline-source.json').read_text());changed=[]
for f,h in baseline['sha256'].items():
 if hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()!=h:changed.append(f)
assert sorted(changed)==['ios/App/ReminderListView.swift','ios/UITests/BoardCapacityPresentationUITests.swift']
before=(p/'ReminderListView-before.swift.txt').read_text();after=pathlib.Path('ios/App/ReminderListView.swift').read_text();literal=lambda s:collections.Counter(re.findall(r'"(?:[^"\\]|\\.)*"',s))
assert literal(before)==literal(after)
freeze=json.loads((p/'freeze.json').read_text());assert all(hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()==h for f,h in freeze['sourceHashes'].items())
(p/'test-acceptance.json').write_text(json.dumps(dict(tests=len(actual),unit=unit,ui=ui,baselines=baselines,namedIDs=actual,allNamedTestsPassed=allPassed,requiredProgrammaticGatesPassed=allPassed and s['failedTests']==s['skippedTests']==0,failed=s['failedTests'],skipped=s['skippedTests'],summary=s,changedExistingSwift=changed,literalMultisetUnchanged=True,freezeMatches=True),indent=2))
print(dict(actualNamedCount=len(actual),unit=unit,ui=ui,allNamedTestsPassed=allPassed,failed=s['failedTests'],skipped=s['skippedTests'],frozenSourceAndStringsUnchanged=True))
