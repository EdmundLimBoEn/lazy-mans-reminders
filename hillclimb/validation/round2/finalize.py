"""Inventory fresh native images and pair only to usable reference captures.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,json,hashlib,struct
root=pathlib.Path('.');out=root/'hillclimb/rounds/2';v=root/'hillclimb/validation/round2'
source=json.loads((v/'provenance.json').read_text())
refs=[]
for directory in [root/'hillclimb/reference',root/'hillclimb/reference/round2']:
 p=directory/'manifest.json'
 if p.exists():
  for c in json.loads(p.read_text()).get('captures',[]):
   if c.get('reference_status')=='usable':refs.append((directory/c['file'],c))
rows=[];pairs=[]
for p in sorted(out.rglob('*.png')):
 b=p.read_bytes();name=p.name;style='dark' if '-dark-' in name else 'light'
 state='empty' if 'empty-' in name else 'sheet' if 'account-' in name else 'compose' if 'composer-' in name or 'signin-' in name else 'bottom' if 'bottom' in name else 'top'
 candidates=[(r,c) for r,c in refs if c.get('appearance')==style and c.get('state')==state]
 gap=[]
 if not candidates:
  candidates=[(r,c) for r,c in refs if c.get('appearance')==style];gap.append('No exact usable state reference')
 match=candidates[0][0] if candidates else None
 if 'medium-' in name:gap.append('Reference Details sheet is large; no exact medium detent match')
 if 'lower' in name:gap.append('Reference Details top differs from scrolled Account footer')
 if 'full-' in name or 'long-text-' in name:gap.append('Seeded app paragraphs differ from shorter reference reminder content')
 if 'signin' in name:gap.append('No Apple sign-in reference; compose compares native form/keyboard treatment only')
 if 'activity/' in str(p):gap.append('No native Apple Activity reference; matched list only for typography, not geometry')
 if 'XXXL' in name:gap.append('Reference default type size; no exact XXXL match')
 if 'empty-' in name:gap.append('No empty reference in matching appearance' if style=='dark' else 'Empty list state differs in app controls')
 rows.append({'file':str(p.relative_to(out)),'sha256':hashlib.sha256(b).hexdigest(),'dimensions':list(struct.unpack('>II',b[16:24])),'status':'captured','sourceSHA':source['source_sha']})
 pairs.append({'image':str(p.relative_to(out)),'reference':str(match) if match else None,'gaps':gap,'reference_status':'usable' if match else 'missing'})
(out/'inventory.json').write_text(json.dumps({'sourceSHA':source['source_sha'],'device':json.loads((v/'device.json').read_text()),'production_source_sha256':source['production_source_sha256'],'images':rows,'count':len(rows)},indent=2)+'\n')
(out/'pairings.json').write_text(json.dumps(pairs,indent=2)+'\n')
(out/'pairings.md').write_text('| Image | Closest usable reference | Gaps |\n|---|---|---|\n'+''.join('| '+x['image']+' | '+str(x['reference'])+' | '+'; '.join(x['gaps'])+' |\n' for x in pairs))
print('Native PNG inventory:',len(rows),'dimensions:',sorted(set(tuple(x['dimensions']) for x in rows)))
