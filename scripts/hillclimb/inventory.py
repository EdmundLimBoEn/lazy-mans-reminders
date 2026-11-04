"""Inventory fresh native images and pair only to usable reference captures.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,json,hashlib,struct,argparse
p=argparse.ArgumentParser();p.add_argument("--round",type=int,required=True);a=p.parse_args()
root=pathlib.Path('.');out=root/'hillclimb/rounds'/str(a.round);v=root/'hillclimb/validation'/str('round'+str(a.round))
source=json.loads((v/'provenance.json').read_text())
refs=[]
for directory in [root/'hillclimb/reference',root/'hillclimb/reference/round2',root/'hillclimb/reference/round3']:
 p=directory/'manifest.json'
 if p.exists():
  for c in json.loads(p.read_text()).get('captures',[]):
   if c.get('reference_status')=='usable':refs.append((directory/c['file'],c))
rows=[];pairs=[]
for p in sorted(out.rglob('*.png')):
 if any(x in p.parts for x in ['contact-sheets','rejected']):continue
 b=p.read_bytes();name=p.name;style='dark' if '-dark-' in name else 'light'
 state='empty' if 'empty-' in name or 'guide-' in name else 'sheet' if 'account-' in name else 'compose' if 'composer-' in name or 'signin-' in name else 'bottom' if 'bottom' in name else 'top'
 candidates=[(r,c) for r,c in refs if c.get('appearance')==style and c.get('state')==state]
 gap=[]
 if not candidates:
  candidates=[(r,c) for r,c in refs if c.get('appearance')==style];gap.append('No exact usable state reference')
 if 'XXXL' in name:
  candidates.sort(key=lambda rc:rc[1].get('size')!='XXXL')
 match=candidates[0][0] if candidates else None
 matched_meta=candidates[0][1] if candidates else {}
 if 'account-' in name:gap.append('Account settings differs semantically from Apple reminder Details')
 if 'board-loading-' in name or 'board-error-' in name:gap.append('No exact Apple loading/error fixture counterpart')
 if 'guide-' in name:gap.append('Apple empty list lacks Notepad setup-guide semantics')
 if 'collapsed' in name:gap.append('Compact/minimal Activity content intentionally EmptyView; no reminder lines visible')
 if 'medium-' in name:gap.append('Reference Details sheet is large; no exact medium detent match')
 if 'lower' in name:gap.append('Reference Details top differs from scrolled Account footer')
 if 'full-' in name or 'long-text-' in name:gap.append('Seeded app paragraphs differ from shorter reference reminder content')
 if 'signin' in name:gap.append('No Apple sign-in reference; compose compares native form/keyboard treatment only')
 if 'activity/' in str(p):gap.append('No native Apple Activity reference; matched list only for typography, not geometry')
 if 'XXXL' in name and matched_meta.get('size')!='XXXL':gap.append('Reference default type size; no exact XXXL match')
 if 'empty-' in name:gap.append('No empty reference in matching appearance' if style=='dark' else 'Empty list state differs in app controls')
 rows.append({'file':str(p.relative_to(out)),'sha256':hashlib.sha256(b).hexdigest(),'dimensions':list(struct.unpack('>II',b[16:24])),'status':'captured','sourceSHA':source['sourceSHA']})
 pairs.append({'image':str(p.relative_to(out)),'reference':str(match) if match else None,'gaps':gap,'reference_status':'usable' if match else 'missing'})
(out/'inventory.json').write_text(json.dumps({'sourceSHA':source['sourceSHA'],'device':json.loads((v/'device.json').read_text()),'production_source_sha256':source['production_source_sha256'],'images':rows,'count':len(rows)},indent=2)+'\n')
(out/'pairings.json').write_text(json.dumps(pairs,indent=2)+'\n')
(out/'pairings.md').write_text('| Image | Closest usable reference | Gaps |\n|---|---|---|\n'+''.join('| '+x['image']+' | '+str(x['reference'])+' | '+'; '.join(x['gaps'])+' |\n' for x in pairs))
print('Native PNG inventory:',len(rows),'dimensions:',sorted(set(tuple(x['dimensions']) for x in rows)))

with (out/'pairings.md').open('a') as f:f.write('\nWritten by gpt-6.1-sol in Codex on behalf of Edmund\n')
