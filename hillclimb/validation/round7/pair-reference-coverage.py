"""Every usable Reminders reference retains a closest native comparison.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json, hashlib
p=Path(__file__).parent;o=Path('hillclimb/rounds/7')
refs=json.loads((p/'reference-inventory.json').read_text());inventory=json.loads((o/'inventory.json').read_text());byfile={x['file']:x for x in inventory['images']};rows=[]
for ref in refs:
 m=ref['metadata'];style=m['appearance'];size=m.get('size','default');state=m['state'];gaps=[]
 if state=='compose':
  name=f'keyboards/{style}-{size}-email.png'
  candidates=[x for x in byfile if x.startswith('keyboards/') and style+'-'+size+'-' in x and 'password' not in x]
  name=name if name in byfile else candidates[0]
  gaps.append('Apple reminder composer and Notepad authentication/composer differ semantically; native keyboard/form treatment only')
 elif state=='sheet':
  name=f'account-enabled/screens/normal-{style}-{size}-large-top.png'
  gaps.append('Apple Details and Notepad Account differ in controls, paragraphs and purpose; no exact medium detent counterpart')
 elif state=='empty':
  name=f'empty-{style}-{size}-top.png';gaps.append('Notepad setup guide and controls differ from Apple empty list')
 elif state=='bottom':
  name=f'board/{style}-{size}-true-bottom-after-pull.png';gaps.append('Seeded app paragraphs differ from shorter Apple reminder content')
 else:
  name=f'board/{style}-{size}-top.png';gaps.append('Seeded app paragraphs differ from shorter Apple reminder content')
 assert name in byfile,(ref['path'],name)
 image=byfile[name];assert image['appearance']==style and image['size']==size
 assert hashlib.sha256(Path(ref['path']).read_bytes()).hexdigest()==ref['sha256']
 assert hashlib.sha256((o/name).read_bytes()).hexdigest()==image['sha256']
 rows.append(dict(reference=ref,closestNative=image,gaps=gaps))
assert len(rows)==17
(p/'reference-coverage.json').write_text(json.dumps(dict(count=17,pairs=rows,globalGaps=['No exact Apple auth, Activity, capacity, medium-detent, combined-system-configuration or Notes reference'],sourceIdentity=inventory['sourceIdentity']),indent=2))
print('All17 usable references paired by appearance, type size and closest available state')
