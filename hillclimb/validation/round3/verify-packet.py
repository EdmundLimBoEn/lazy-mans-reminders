"""Integrity only; never rates images or overrides failing test gates.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,json,hashlib,struct,subprocess
p=pathlib.Path('hillclimb/rounds/3');v=pathlib.Path('hillclimb/validation/round3');src=json.load(open(v/'provenance.json'));sha=src['sourceSHA']
for group in ['production_source_sha256','backend_source_sha256']:
 for name,h in src[group].items():
  assert hashlib.sha256(pathlib.Path(name).read_bytes()).hexdigest()==h
  assert hashlib.sha256(subprocess.check_output(['git','show',sha+':'+name])).hexdigest()==h
for row in json.load(open(p/'all-png-hashes.json')):
 b=pathlib.Path(row['file']).read_bytes();assert hashlib.sha256(b).hexdigest()==row['sha256'];assert list(struct.unpack('>II',b[16:24]))==row['dimensions']
inv=json.load(open(p/'inventory.json'));assert inv['sourceSHA']==sha and len(inv['images'])==102
assert len(json.load(open(p/'extras/manifest.json'))['captures'])==72
assert len([c for c in json.load(open(p/'manifest.json'))['captures'] if c['status']=='captured'])==18
pairs=json.load(open(p/'pairings.json'));assert len(pairs)==102
usable=set()
for directory in [pathlib.Path('hillclimb/reference'),pathlib.Path('hillclimb/reference/round2'),pathlib.Path('hillclimb/reference/round3')]:
 for c in json.load(open(directory/'manifest.json'))['captures']:
  if c['reference_status']=='usable':usable.add(str(directory/c['file']))
for row in pairs:assert row['reference'] in usable and pathlib.Path(row['reference']).is_file()
summary=json.load(open(v/'combined-summary.json'));assert summary['totalTestCount']==276 and summary['passedTests']==275 and summary['failedTests']==1 and summary['skippedTests']==0
checks=json.load(open(p/'checks.json'));assert checks['source_sha']==sha and any(c['status']=='failed' for c in checks['checks'] if c.get('required',True))
assert not json.load(open(p/'activity/cleanup.json'))['ownedIDsRemainingInDemoDefaults']
result={'status':'passed','meaning':'Evidence integrity only; full UI/combined gates remain failed','sourceSHA':sha,'qualifyingImages':102,'hashVerifiedPNGs':len(json.load(open(p/'all-png-hashes.json'))),'pairs':len(pairs),'usableNewXXXLReferences':8,'productionFilesVerifiedAgainstBuildCommit':len(src['production_source_sha256'])+len(src['backend_source_sha256'])}
(v/'packet-integrity.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
