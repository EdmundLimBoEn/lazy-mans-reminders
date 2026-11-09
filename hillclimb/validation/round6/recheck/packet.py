"""Recheck supplement; preserve historical capture identities.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,hashlib,copy
from PIL import Image
p=pathlib.Path(__file__).parent; out=pathlib.Path('hillclimb/rounds/6'); sha=lambda f:hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest(); freeze=json.loads((p/'freeze.json').read_text()); graded=freeze['sourceSHA']
inv=json.loads((out/'inventory.json').read_text()); historic=inv['images']; assert len([r for r in historic if r.get('family')!='recheck-gesture'])==537
inv['supplements']=[dict(inventory='../../validation/round6/recheck/native-inventory.json',purpose='Required ordinary gesture proof; native originals carry actual capture SHA and paired references')];inv['gradingSourceSHA']=graded;inv['historicalCaptureSHA']=freeze['historicalCaptureSHA'];inv['productionHashEquivalence']='../../validation/round6/recheck/provenance.json'
# Historical sourceSHA and per-image metadata remain unchanged.
rows=[]
d=p/'focused-SignInChromeUITests';manifest=json.loads((d/'manifest.json').read_text())
for test in manifest:
 for a in test['attachments']:
  f=d/a['exportedFileName']
  if f.suffix!='.png':continue
  title=a['suggestedHumanReadableName']; rows.append(dict(file=str(f),sha256=sha(f),dimensions=list(Image.open(f).size),captureSHA=graded,sourceSHA=graded,gradingSourceSHA=graded,test=test['testIdentifier'],name=title,binaryIdentity='tested-artifacts.json',pairedReferences=[r['file'] for r in json.loads((p/'reference-integrity.json').read_text()) if ('dark' if 'dark' in title else 'light') in r['file']],limits='Ordinary controls disabled; paint comparison explicitly positioned and noninteractive. Screenshot runtime status bar may remain system-light while app is dark.'))
manual=json.loads((p/'manual-native.json').read_text()) if (p/'manual-native.json').exists() else []
rows += manual
inv['supplements'][0]['count']=len(rows);inv['totalNativeWithRecheck']=537+len(rows)
(p/'native-inventory.json').write_text(json.dumps(dict(count=len(rows),images=rows,historicalNativeCount=537,historicalRecordings=9,referenceCount=17),indent=2));(out/'inventory.json').write_text(json.dumps(inv,indent=2))
