"""Matched native originals and labeled review derivatives.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
p=Path(__file__).parent;before=p/'before-complete';after=p/'after-complete';out=p/'paired-contact-sheets';out.mkdir(exist_ok=True);rows=[]
priority=['light-default-enabled-default.png','dark-default-enabled-default.png','light-default-password.png','dark-default-password.png']
files=sorted(before.glob('*.png'),key=lambda f:(priority.index(f.name) if f.name in priority else 99,f.name))
for f in files:
 g=after/f.name
 assert g.exists(),g
 rows.append(dict(state=f.stem,before=str(f),after=str(g),beforeSHA256=hashlib.sha256(f.read_bytes()).hexdigest(),afterSHA256=hashlib.sha256(g.read_bytes()).hexdigest(),beforeSourceSHA='c8da74021a7d66d95d040817405044bbb3af3f9f',afterSourceIdentity=json.loads((p/'freeze.json').read_text())['sourceIdentity'],comparison='Matched app-local style/type/variant and action protocol; live keyboard/secure reveal/scroll positions retain actual native behavior'))
for offset in range(0,len(rows),6):
 page=Image.new('RGB',(1000,1380),'#777777');draw=ImageDraw.Draw(page)
 for n,r in enumerate(rows[offset:offset+6]):
  for j,side in enumerate(['before','after']):
   im=Image.open(r[side]).convert('RGB');im.thumbnail((245,410));x=(n%2*2+j)*250;y=n//2*460;page.paste(im,(x,y));draw.text((x,y+412),side+' '+r['state'][:27],fill='white');draw.text((x,y+430),r['state'][27:],fill='white')
 page.save(out/f'page-{offset//6+1:02}.jpg')
(p/'login-pairings.json').write_text(json.dumps(dict(pairs=rows,count=len(rows),unmatchedFilledPreviews=[str(f) for f in after.glob('*filled-*.png')],gap='Frozen S has no seeded filled-enabled appearance argument and its paint root must remain inert. New filled-primary previews have no exact old enabled-primary counterpart; populated ordinary password pairs remain matched.'),indent=2))
assert len(rows)>=16
print(len(rows),'matched pairs; originals unchanged')
