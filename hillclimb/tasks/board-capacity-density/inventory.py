"""Compact native image and raw local result provenance.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,hashlib,subprocess
from PIL import Image
p=pathlib.Path(__file__).parent;sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();rows=[];source=json.loads((p/'freeze.json').read_text())['sourceSHA']
refs=json.loads((p/'reference-integrity.json').read_text())
for phase in ['baseline','final']:
 for f in sorted((p/(phase+'-captures')).glob('*.png')):
  assert Image.open(f).size==(1206,2622)
  style='dark' if '-dark-' in f.name else 'light';size='XXXL' if '-XXXL-' in f.name else 'default'
  rows.append(dict(file=str(f),sha256=sha(f),dimensions=Image.open(f).size,sourceSHA=source if phase=='final' else json.loads((p/'baseline-source.json').read_text())['sourceSHA'],phase=phase,style=style,size=size,native=True,retouched=False,binaryIdentity='tested-artifacts.json' if phase=='final' else 'baseline-inputs.json',closestAppleReferences=[r['file'] for r in refs if style in r['file'] and ('compose' in r['file'] if 'draft' in f.name else 'top' in r['file'])],gaps='No exact capacity reference or Notes; Apple content shorter and varied. No row-gutter/content-parity inference.'))
assert len(rows)==32
(p/'native-inventory.json').write_text(json.dumps(dict(images=rows,count=32,before=16,final=16),indent=2))
external=[]
for d in sorted(pathlib.Path('/tmp').glob('hillclimb-capacity-density-T-*.xcresult')):
 files=[dict(file=str(f),bytes=f.stat().st_size,sha256=sha(f)) for f in sorted(d.rglob('*')) if f.is_file()];external.append(dict(path=str(d),totalBytes=sum(r['bytes'] for r in files),files=files))
(p/'external-results.json').write_text(json.dumps(external,indent=2))
print('32 native originals and local raw result hashes inventoried')
