"""Review derivatives for eight ordinary filled-form before/after pairs.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
p=Path(__file__).parent;before=json.loads((p/'before-filled-ordinary/manifest.json').read_text());after=json.loads((p/'after-filled-ordinary/manifest.json').read_text());byname={Path(x['file']).name:x for x in after};rows=[];out=p/'filled-paired-contact-sheets';out.mkdir(exist_ok=True)
for b in before:
 a=byname[Path(b['file']).name]
 for x in [a,b]:assert hashlib.sha256(Path(x['file']).read_bytes()).hexdigest()==x['sha256']
 rows.append(dict(state=Path(b['file']).stem,before=b,after=a,matchedInputProtocol=True,gap='Both ordinary fixtures accept actual local input but semantically disable submit. New inert filled-enabled primary preview has no exact frozen-S counterpart.'))
assert len(rows)==8
for offset in range(0,len(rows),6):
 page=Image.new('RGB',(1000,1380),'#777777');d=ImageDraw.Draw(page)
 for n,r in enumerate(rows[offset:offset+6]):
  for j,side in enumerate(['before','after']):
   im=Image.open(r[side]['file']).convert('RGB');im.thumbnail((245,410));x=(n%2*2+j)*250;y=n//2*460;page.paste(im,(x,y));d.text((x,y+412),side+' filled '+r['state'],fill='white')
 page.save(out/f'page-{offset//6+1:02}.jpg')
(p/'filled-pairings.json').write_text(json.dumps(dict(count=8,pairs=rows),indent=2));print('8 matched real-input filled pairs; total52 matched login pairs')
