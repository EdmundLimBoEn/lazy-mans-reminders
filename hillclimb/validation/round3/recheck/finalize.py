"""Update only sourced round3 gates after every required native gate passes.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,json,hashlib,subprocess
p=pathlib.Path(__file__).parent;r=pathlib.Path('hillclimb/rounds/3')
s=json.loads((p/'combined-summary.json').read_text());assert (s['totalTestCount'],s['passedTests'],s['failedTests'],s['skippedTests'])==(276,276,0,0)
assert json.loads((p/'python-ios.json').read_text())['exit']==0
proof=json.loads((p/'matrix-proof.json').read_text());assert len(proof)==4
for mode in ['matrix1','matrix2','matrix3','combined']:
 d=json.loads((p/(mode+'-runtime-summary.json')).read_text());assert d['runtimeWarnings']==[] and d['invalidFrameEvents']==0
m=json.loads((r/'recheck/manifest.json').read_text());assert len(m['captures'])==8
inv=json.loads((r/'inventory.json').read_text());assert inv['sourceSHA']=='6959de17bb4d74fa1518914988645a3ea0313a68'
for f,h in inv['production_source_sha256'].items():assert hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()==h
for c in m['captures']:
 f=r/'recheck'/c['file'];assert hashlib.sha256(f.read_bytes()).hexdigest()==c['sha256']
 inv['images'].append({'file':'recheck/'+c['file'],'sha256':c['sha256'],'dimensions':c['pixels'],'status':'captured','sourceSHA':inv['sourceSHA'],'testRevision':m['testRevision'],'validationRevision':m['validationRevision'],'visuallyInspected':True,'kind':'native-app-simulator','afterActualScroll':True})
inv['count']=len(inv['images']);assert inv['count']==110
(r/'inventory.json').write_text(json.dumps(inv,indent=2)+'\n')
pairs=json.loads((r/'pairings.json').read_text())
for c in m['captures']:
 original=next(x for x in pairs if x['image']=='extras/'+c['file']);pairs.append({**original,'image':'recheck/'+c['file'],'gaps':original['gaps']+['Recheck after actual form scroll; no authentication counterpart']})
(r/'pairings.json').write_text(json.dumps(pairs,indent=2)+'\n')
with (r/'pairings.md').open('a') as f:
 for row in pairs[-8:]:f.write('| '+row['image']+' | '+str(row['reference'])+' | '+'; '.join(row['gaps'])+' |\n')
checks=json.loads((r/'checks.json').read_text());checks['testRevision']=m['testRevision'];checks['validationRevision']=m['validationRevision'];checks['validationEvidenceCommit']='This commit (git log -- hillclimb/validation/round3/recheck)';checks['historicalFailedBaseline']='../../validation/round3/combined-summary.json'
for c in checks['checks']:
 name=c['name']
 if name=='full existing unit suite':c.update(status='passed',count=260,evidence='../../validation/round3/recheck/combined-tests.json')
 if name=='full existing UI suite':c.update(status='passed',passed=16,failed=0,selected=16,skipped=0,evidence='../../validation/round3/recheck/combined-tests.json')
 if name=='combined scheme test execution':c.update(status='passed',count=276,passed=276,failed=0,skipped=0,evidence='../../validation/round3/recheck/combined-summary.json')
 if name=='fresh unsigned arm64 Debug build-for-testing':c['evidence']='../../validation/round3/recheck/build-Debug.json'
 if name=='iOS Python checks':c['evidence']='../../validation/round3/recheck/python-ios.json'
 if name=='keyboard runtime issues and scoped invalid-frame logs':c.update(status='passed',runtimeWarnings=0,invalidFrameEvents=0,evidence='../../validation/round3/recheck/combined-runtime-summary.json',limitation='All eight cases completed in three dedicated runs and the full suite; other error/fault events retained.')
 if name=='fresh unsigned arm64 Release build and artifact':c['reuseProvenance']='../../validation/round3/recheck/historical-provenance.json; no new Release execution'
checks['checks'].append({'name':'three fresh-process exact strengthened keyboard matrices','status':'passed','runs':3,'iterations':24,'failed':0,'skipped':0,'evidence':'../../validation/round3/recheck/matrix-proof.json'})
for c in checks['checks']:
 for e in c.get('evidence','').split('; '):
  if '*' not in e:assert (r/e).exists(),e
(r/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
print('Updated passing gates, 110 native images, 110 pairings; preserved failed baseline')
