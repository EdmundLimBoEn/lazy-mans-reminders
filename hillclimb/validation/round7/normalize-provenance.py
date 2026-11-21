"""Bind capture metadata to actual frozen bytes when HEAD excludes corrections.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,subprocess,hashlib
p=Path(__file__).parent;t=Path('hillclimb/tasks/login-composition');o=Path('hillclimb/rounds/7');freeze=json.loads((t/'freeze.json').read_text())
assert all(hashlib.sha256(Path(f).read_bytes()).hexdigest()==h for f,h in freeze['hashes'].items())
for f in o.rglob('*.json'):
 if 'rejected' in f.parts:continue
 if 'manifest' not in f.name and not f.name.startswith('captures-'):continue
 r=json.loads(f.read_text())
 if not isinstance(r,dict):continue
 r.setdefault('acquisitionReportedHead',r.get('sourceSHA',r.get('productionSource',r.get('sourceInputs'))))
 for key in ['sourceSHA','productionSource','testRevision','sourceInputs']:
  if key in r:r[key]=None
 r.update(sourceIdentity=freeze['sourceIdentity'],sourceSHA=None,parentSourceSHA=freeze['sourceSHA'],correctedSourceUncommitted=True,freeze=str(t/'freeze.json'),binaryIdentity=str(t/'tested-artifacts.json'))
 f.write_text(json.dumps(r,indent=2))
provenance=json.loads((p/'provenance.json').read_text());provenance['production_source_sha256']=json.loads((t/'production54.json').read_text())['hashes'];(p/'provenance.json').write_text(json.dumps(provenance,indent=2))
subprocess.run(['python3','scripts/hillclimb/inventory.py','--round','7'],check=True)
f=o/'inventory.json';r=json.loads(f.read_text());xctest={x['file']:x for x in json.loads((p/'xctest-native-inventory.json').read_text())}
for item in r['images']:
 file=o/item['file'];item.update(sourceIdentity=freeze['sourceIdentity'],parentSourceSHA=freeze['sourceSHA'],binaryIdentity=str(t/'tested-artifacts.json'),sourceSHA=None)
 if item['kind']=='native-system-setting-proof':
  item.update(renderingApp='com.apple.Preferences',testedAppBinaryIdentity=str(t/'tested-artifacts.json'),binaryIdentity='Native system Settings iOS26.2/23C54; system app hash was not sampled',sourceScope='Frozen source identifies the app/test protocol, not the OS Settings renderer')
 elif item['kind']=='native-activity':
  item.update(renderingApp='com.apple.springboard with tested ReminderWidgetExtension',sourceScope='Tested widget extension and Activity fixture plus native OS surface')
 if str(file) in xctest:
  x=xctest[str(file)];item.update(protectedPartial=x['protectedPartial'],testIdentifier=x['testIdentifier'],rawExport=x['rawExport'])
  if x['protectedPartial']:
   item['partialEvidenceScope']='Protected XCTest secure content is partial; independent pinned full-device captures provide complete visual supplements'
 if file.parent.name in ['activity','activity-long'] and 'expanded' in file.name:
  video=file.with_suffix('.mp4');item['recordingSHA256']=hashlib.sha256(video.read_bytes()).hexdigest();item['recordingFrameSeconds']=2
r.update(sourceIdentity=freeze['sourceIdentity'],sourceSHA=None,correctedSourceUncommitted=True,beforeInventory=str(t/'before-inventory.json'),loginAfterInventory=str(t/'after-complete.json'),countMeaning='PNG records include repeated acquisitions, loading samples and state transitions; not a count of unique screens. Protected secure XCTest images remain partial. Before S witness is separate actual source/binary.')
f.write_text(json.dumps(r,indent=2))
pairfile=o/'pairings.json';pairs=json.loads(pairfile.read_text());byname={x['file']:x for x in r['images']}
for pair in pairs:
 item=byname[pair['image']]
 if item.get('protectedPartial') and not any('partial' in g for g in pair['gaps']):pair['gaps'].append('Protected XCTest secure content is partial; native AX and full-device manual supplements are separate proof')
 if 'LoginCompositionUITests' in pair['image']:
  pair['gaps'].append('No Apple sign-in reference; native Compose is a form/keyboard treatment reference only')
  refs=json.loads((p/'reference-inventory.json').read_text())
  candidates=[x for x in refs if x['metadata'].get('appearance')==item['appearance'] and x['metadata'].get('state')=='compose']
  candidates.sort(key=lambda x:x['metadata'].get('size','default')!=item['size'])
  if candidates:
   ref=candidates[0];pair.update(reference=ref['path'],reference_sha256=ref['sha256'],referenceAppearance=ref['metadata']['appearance'],referenceSize=ref['metadata'].get('size','default'))
pairfile.write_text(json.dumps(pairs,indent=2))
(o/'pairings.md').write_text('| Image | Closest usable reference | Gaps |\n|---|---|---|\n'+''.join('| '+x['image']+' | '+str(x['reference'])+' | '+'; '.join(x['gaps'])+' |\n' for x in pairs)+'\nWritten by gpt-6.1-sol in Codex on behalf of Edmund\n')
print('Capture provenance uses actual frozen bytes; parent HEAD is explicitly separate')
