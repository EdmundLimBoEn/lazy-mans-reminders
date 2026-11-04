"""Inventory fresh native images and pair only to usable reference captures.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,json,hashlib,struct,argparse,re
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
meta_path=out/"native-metadata.json"
native_meta=json.loads(meta_path.read_text()) if meta_path.exists() else {}
for p in sorted(out.rglob('*.png')):
 if any(x in p.parts for x in ['contact-sheets','rejected']):continue
 b=p.read_bytes();name=str(p.relative_to(out));style='dark' if re.search(r'(^|[-/])dark([-/.]|$)',name) else 'light'
 style=native_meta.get(name,{}).get('appearance',style)
 size=native_meta.get(name,{}).get('size','XXXL' if 'XXXL' in name else 'default')
 state='empty' if 'empty-' in name or 'guide-' in name else 'sheet' if 'account-' in name or ('settings-' in name or 'settings/' in name) else 'compose' if 'composer-' in name or 'signin-' in name or 'nonempty-' in name or 'keyboards/' in name else 'bottom' if 'bottom' in name else 'top'
 candidates=[(r,c) for r,c in refs if c.get('appearance')==style and c.get('state')==state]
 gap=[]
 if not candidates:
  candidates=[(r,c) for r,c in refs if c.get('appearance')==style];gap.append('No exact usable state reference')
 candidates.sort(key=lambda rc:(rc[1].get('size','default') != size))
 match=candidates[0][0] if candidates else None
 matched_meta=candidates[0][1] if candidates else {}
 if any(part in name for part in ['accessibility/','settings/','captures-solid/','combined-keyboards/']):gap.append('Actual combined system accessibility configuration; no exact reference configuration counterpart')
 if 'accessibility/' in name and 'password-keyboard' in name:gap.append('Protected password keyboard omitted by XCTest screenshot; partial visual evidence; native geometry and interactions are separate proof')
 if ('settings-' in name or 'settings/' in name):gap.append('Native iOS Settings proof, not app-rendered UI; Reminders Details is only a form reference')
 if 'board/' in name and not any(x in name for x in ['guide','nonempty']):gap.append('Seeded app paragraphs differ from shorter reference content')
 if 'account-' in name:gap.append('Account settings differs semantically from Apple reminder Details')
 if 'board-loading-' in name or 'board-error-' in name:gap.append('No exact Apple loading/error fixture counterpart')
 if 'guide-' in name:gap.append('Apple empty list lacks Notepad setup-guide semantics')
 if 'collapsed' in name:gap.append('Compact/minimal Activity content intentionally EmptyView; no reminder lines visible')
 if 'medium-' in name:gap.append('Reference Details sheet is large; no exact medium detent match')
 if 'lower' in name:gap.append('Reference Details top differs from scrolled Account footer')
 if 'full-' in name or 'long-text-' in name:gap.append('Seeded app paragraphs differ from shorter reference reminder content')
 if 'signin' in name:gap.append('No Apple sign-in reference; compose compares native form/keyboard treatment only')
 if 'activity/' in str(p):gap.append('No native Apple Activity reference; matched list only for typography, not geometry')
 if size=='XXXL' and matched_meta.get('size')!='XXXL':gap.append('Reference default type size; no exact XXXL match')
 if 'empty-' in name:gap.append('No empty reference in matching appearance' if style=='dark' else 'Empty list state differs in app controls')
 rows.append({'file':str(p.relative_to(out)),'sha256':hashlib.sha256(b).hexdigest(),'dimensions':list(struct.unpack('>II',b[16:24])),'status':'captured','sourceSHA':source['sourceSHA'],'kind':'native-system-setting-proof' if ('settings-' in name or 'settings/' in name) else 'native-activity' if 'activity/' in name else 'native-app'})
 pairs.append({'image':str(p.relative_to(out)),'reference':str(match) if match else None,'gaps':gap,'reference_status':'usable' if match else 'missing','reference_sha256':hashlib.sha256(match.read_bytes()).hexdigest() if match else None})
(out/'inventory.json').write_text(json.dumps({'sourceSHA':source['sourceSHA'],'device':json.loads((v/'device.json').read_text()),'production_source_sha256':source['production_source_sha256'],'images':rows,'count':len(rows)},indent=2)+'\n')
(out/'pairings.json').write_text(json.dumps(pairs,indent=2)+'\n')
(out/'pairings.md').write_text('| Image | Closest usable reference | Gaps |\n|---|---|---|\n'+''.join('| '+x['image']+' | '+str(x['reference'])+' | '+'; '.join(x['gaps'])+' |\n' for x in pairs))
print('Native PNG inventory:',len(rows),'dimensions:',sorted(set(tuple(x['dimensions']) for x in rows)))

with (out/'pairings.md').open('a') as f:f.write('\nWritten by gpt-6.1-sol in Codex on behalf of Edmund\n')
