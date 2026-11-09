"""Verify frozen inputs, every qualifying PNG and usable reference pairing.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,json,hashlib,struct,subprocess,collections
P=pathlib.Path(__file__).parent;O=pathlib.Path('hillclimb/rounds/4');source=json.loads((P/'provenance.json').read_text());checks=json.loads((O/'checks.json').read_text());inventory=json.loads((O/'inventory.json').read_text());assert checks['source_sha']==source['sourceSHA']==inventory['sourceSHA']
for kind in ['production_source_sha256','backend_sha256']:
 for path,sha in source[kind].items():assert hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()==sha,path
for record in inventory['images']:
 p=O/record['file'];b=p.read_bytes();assert hashlib.sha256(b).hexdigest()==record['sha256'];assert list(struct.unpack('>II',b[16:24]))==record['dimensions']==[1206,2622],p
pairs=json.loads((O/'pairings.json').read_text());assert len(pairs)==len(inventory['images'])
for pair in pairs:
 assert pair['reference_status']=='usable';assert hashlib.sha256(pathlib.Path(pair['reference']).read_bytes()).hexdigest()==pair['reference_sha256']
refs=json.loads((P/'reference-integrity.json').read_text())
for ref in refs:assert hashlib.sha256(pathlib.Path(ref['file']).read_bytes()).hexdigest()==ref['expected']
summary=json.loads((P/'combined-summary.json').read_text());assert summary['totalTestCount']==summary['passedTests']==285 and summary['failedTests']==summary['skippedTests']==0
assert not subprocess.check_output(['git','diff','--name-only','--','ios','supabase'],text=True).strip()
result=dict(sourceSHA=source['sourceSHA'],testRevision=checks['testRevision'],productionFiles=len(source['production_source_sha256']),backendFiles=len(source['backend_sha256']),nativeImages=len(inventory['images']),pairs=len(pairs),dimensions=[1206,2622],allHashesMatch=True,countsByFolder=dict(collections.Counter(r['file'].split('/')[0] if '/' in r['file'] else 'core' for r in inventory['images'])))
(P/'packet-integrity.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
