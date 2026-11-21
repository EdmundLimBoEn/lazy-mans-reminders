"""Pair retained R/T before originals with fresh combined-source native captures.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,hashlib
p=Path(__file__).parent;native=json.loads((p/'xctest-native-inventory.json').read_text());rows=[]
def local(path):
 s=str(path);return Path(s[s.index('hillclimb/'):])
def fresh(group,name):
 candidates=[x for x in native if '/new-'+group+'/' in x['file'] and x['attachmentName'].split('_',1)[0].removesuffix('.png')==name]
 assert len(candidates)==1,(group,name,len(candidates));return candidates[0]
r=json.loads(Path('hillclimb/tasks/account-density/pairings.json').read_text())
for old in r['pairs']:
 f=local(old['before']['path']);assert hashlib.sha256(f.read_bytes()).hexdigest()==old['before']['sha256'];new=fresh('AccountChromeUITests',old['name'])
 rows.append(dict(task='R',state=old['name'],before=str(f),beforeSHA256=old['before']['sha256'],beforeSourceSHA=old['before']['appSourceSHA'],beforeBinaryRecord='hillclimb/tasks/account-density/'+old['before']['binaryRecord'],after=new,matchedContentTarget=old['matchedContentTarget'],positionScope=old['positionScope'],gap='Before retained at its actual earlier source/binary on original17. New combined app includes additional SignIn/board candidates; Account production bytes exactly equal frozen R. No old image is relabeled as new-source proof.'))
r=json.loads(Path('hillclimb/tasks/board-capacity-density/native-inventory.json').read_text())
for old in r['images']:
 if old['phase']!='baseline':continue
 f=local(old['file']);assert hashlib.sha256(f.read_bytes()).hexdigest()==old['sha256'];new=fresh('BoardCapacityDensityUITests',f.stem)
 rows.append(dict(task='T',state=f.stem,before=str(f),beforeSHA256=old['sha256'],beforeSourceSHA=old['sourceSHA'],beforeBinaryRecord='hillclimb/tasks/board-capacity-density/'+old['binaryIdentity'],after=new,matchedContentTarget=True,gap='Historical before is private Board17, same regular17Pro/iOS26.2 dimensions; fresh after is original17. Device/configuration acquisition gap is explicit. Board production bytes equal frozen T; no historical frame is new-source proof.'))
assert sum(x['task']=='R' for x in rows)==36 and sum(x['task']=='T' for x in rows)==16
(p/'density-before-after-pairings.json').write_text(json.dumps(rows,indent=2));print('36 R and16 T retained-before/fresh-after pairs; acquisition gaps explicit')
