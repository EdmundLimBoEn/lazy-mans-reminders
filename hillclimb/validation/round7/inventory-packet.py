"""Index final, comparison and rejected native originals without conflating them.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,hashlib,struct,collections
p=Path(__file__).parent;t=Path('hillclimb/tasks/login-composition');o=Path('hillclimb/rounds/7');freeze=json.loads((t/'freeze.json').read_text());rows=[]
def add(item,path,disposition,source=None,binary=None):
 path=Path(path);raw=path.read_bytes();h=hashlib.sha256(raw).hexdigest();assert h==item['sha256'],path
 rows.append(dict(item,file=str(path),sha256=h,dimensions=list(struct.unpack('>II',raw[16:24])),disposition=disposition,sourceIdentity=source or item.get('sourceIdentity'),binaryIdentity=binary or item.get('binaryIdentity') or item.get('binaryProof') or item.get('binaryProofRecord'),acquisition=item.get('acquisition') or item.get('origin') or 'Own pinned agent-device, original17'))
for item in json.loads((o/'inventory.json').read_text())['images']:add(item,o/item['file'],'final combined-source native evidence',freeze['sourceIdentity'],str(t/'tested-artifacts.json'))
for name,disposition in [('before-inventory.json','matched frozen-S before witness; not new-source proof'),('after-complete.json','final combined-source login original'),('rejected-first-complete.json','rejected V1 composition original'),('experimental-native-inventory.json','experimental V2 preview; not final source proof')]:
 for item in json.loads((t/name).read_text()):add(item,item['file'],disposition,binary=item.get('binaryProof') or item.get('binaryBuildInputs'))
for phase in ['before','after']:
 manifest=t/(phase+'-filled-ordinary')/'manifest.json'
 if manifest.exists():
  for item in json.loads(manifest.read_text()):add(item,item['file'],'matched ordinary filled '+phase,source=None if phase=='before' else freeze['sourceIdentity'],binary=str(t/item['binaryIdentity']))
for item in json.loads((p/'xctest-native-inventory-v1.json').read_text()):add(item,item['file'],'rejected V1 native XCTest original',binary=str(t/'tested-artifacts-v1.json'))
for item in json.loads((o/'manifest.json').read_text())['captures']:
 if item['status']=='rejected':add(item,o/item['path'],'superseded V2 acquisition without final-row geometry; retained',freeze['sourceIdentity'],str(t/'tested-artifacts.json'))
for item in json.loads((p/'reference-inventory.json').read_text()):add(item,item['path'],'usable Apple Reminders reference',binary='Historical native Apple Reminders capture; original reference manifest retains acquisition metadata')
for pair in json.loads((p/'density-before-after-pairings.json').read_text()):
 item=dict(sha256=pair['beforeSHA256'],sourceSHA=pair['beforeSourceSHA'],acquisition=pair['gap'])
 add(item,pair['before'],'retained '+pair['task']+' before comparison; not combined-source proof',binary=pair['beforeBinaryRecord'])
assert len({r['file'] for r in rows})==len(rows)
summary=dict(sourceIdentity=freeze['sourceIdentity'],count=len(rows),countMeaning='File acquisitions, not unique screens or quality votes. Rejected, experimental, historical references and before witnesses are separately labeled. Raw attachment exports and Unit ImageRenderer output remain outside the graded native matrix.',optionalSupplementStatus=str(t/'optional-filled-pair-status.json'),byDisposition=dict(collections.Counter(r['disposition'] for r in rows)),images=rows)
(p/'packet-native-inventory.json').write_text(json.dumps(summary,indent=2));print(summary['count'],summary['byDisposition'])
