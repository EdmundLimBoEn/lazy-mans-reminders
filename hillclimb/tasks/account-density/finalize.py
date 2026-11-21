import sys
finalPhase=sys.argv[1] if len(sys.argv)>1 else "full"
"""Validate native results and provenance without grading. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
import json,re,hashlib,gzip,subprocess
p=Path(__file__).parent
sha=lambda f:hashlib.sha256(Path(f).read_bytes()).hexdigest()
freeze=json.loads((p/'freeze.json').read_text())
assert all(sha(f)==h for f,h in freeze['sourceAndTests'].items())
def cases(file):
 out={}
 def walk(n):
  if isinstance(n,dict):
   if n.get('nodeType')=='Test Case':out[n['nodeIdentifierURL']]=n['result']
   for c in n.get('children',[]):walk(c)
  elif isinstance(n,list):
   for c in n:walk(c)
 walk(json.loads(file.read_text())['testNodes']);return out
baseline=cases(p.parent.parent/'validation/round6/recheck/combined-tests.json');new=cases(p/(finalPhase+'-tests.json'))
assert len(baseline)==308 and baseline.keys()<=new.keys()
assert len(new)==310
allPassed=set(new.values())=={'Passed'}
assert cases(p.parent.parent/'validation/round6/combined-tests.json').keys()<=new.keys()
assert cases(p.parent/'activity-tightening/candidate-full-tests.json').keys()<=new.keys()
(p/'acceptance.json').write_text(json.dumps(dict(total=310,unit=263,UI=47,all308NamedIDsRetained=True,all307304293TransitiveIDsRetained=True,allPassed=allPassed,requiredFullSuiteGatePassed=allPassed,validationStatus=('passed' if allPassed else 'pending serialized recheck'),mergeEligible=False,results={v:list(new.values()).count(v) for v in set(new.values())},namedIDs=new,added=sorted(new.keys()-baseline.keys())),indent=2))
observations={};contrasts=[];rhythm={};identity=[]
for d in p.glob('*-Account*UITests'):
 if not d.is_dir() or not (d/'manifest.json').exists():continue
 observations[d.name]={'manifest':json.loads((d/'manifest.json').read_text()),'text':{f.name:f.read_text() for f in d.glob('*.txt')}}
 if d.name!=finalPhase+'-AccountDensityUITests':continue
 for t in observations[d.name]['manifest']:
  for a in t['attachments']:
   f=d/a['exportedFileName'];name=a.get('suggestedHumanReadableName','')
   if f.suffix!='.txt':continue
   s=f.read_text()
   if 'contrast=' in s:
    ratio=float(re.search(r'contrast=([\d.]+)',s)[1]);assert ratio>=7;contrasts.append(dict(name=name,contrast=ratio))
   if 'gap=' in s:
    gap=float(re.search(r'gap=([\d.]+)',s)[1]);boundary=float(re.search(r'boundary=([\d.]+)',s)[1]);assert gap>=16 and boundary>=16;rhythm[name.split('-section-rhythm')[0]]=dict(gap=gap,persistenceBoundary=boundary)
   if '-identity-background_' in name:identity.append(dict(name=name,proof=s))
assert len(contrasts)==24 and len(rhythm)==4 and len(identity)==4
base={}
d=p/'before-rhythm-AccountDensityUITests'
for t in json.loads((d/'manifest.json').read_text()):
 for a in t['attachments']:
  f=d/a['exportedFileName'];name=a.get('suggestedHumanReadableName','')
  if f.suffix=='.txt':
   s=f.read_text();base[name.split('-section-rhythm')[0]]=dict(gap=float(re.search(r'gap=([\d.]+)',s)[1]),persistenceBoundary=float(re.search(r'boundary=([\d.]+)',s)[1]))
assert base.keys()==rhythm.keys()
for k in base:assert rhythm[k]['gap']>base[k]['gap'] and rhythm[k]['persistenceBoundary']>base[k]['persistenceBoundary']
(p/'density-native-gates.json').write_text(json.dumps(dict(baseline=base,final=rhythm,helperMinimumContrast=min(r['contrast'] for r in contrasts),helperContrasts=contrasts,identity=identity),indent=2))
(p/'observations.json.gz').write_bytes(gzip.compress(json.dumps(observations,indent=2).encode(),mtime=0))
artifacts={}
for dd in [Path('/tmp/account-r-800c5513-DD/Build/Products')]:
 for f in dd.rglob('*'):
  if f.is_file() and (f.suffix in ['.dylib','.xctestrun','.plist'] or f.name in ['LazyMansReminders','HillclimbUITests','LazyMansRemindersTests','ReminderWidgetExtension']):artifacts[str(f)]=sha(f)
(p/'tested-artifacts.json').write_text(json.dumps(artifacts,indent=2))
container=subprocess.check_output(['xcrun','simctl','get_app_container','78F5A64F-7B2E-4562-8EF9-10F3312CC694','systems.edmundlim.NotepadHillclimb','app'],text=True).strip();installed={}
for f in Path(container).rglob('*'):
 if f.is_file() and (f.suffix=='.dylib' or f.name in ['LazyMansReminders','ReminderWidgetExtension','Info.plist']):
  rel=f.relative_to(container);product=Path('/tmp/account-r-800c5513-DD/Build/Products/Debug-iphonesimulator/LazyMansReminders.app')/rel
  assert sha(f)==sha(product),str(rel);installed[str(rel)]=sha(f)
(p/'installed-match.json').write_text(json.dumps(dict(container=container,files=installed,allMatch=True),indent=2))
print('Full results:', {v:list(new.values()).count(v) for v in set(new.values())}, '; 308 retained; density checks and installed products verified')
