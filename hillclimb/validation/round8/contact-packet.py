"""Labeled inspection sheets. Native originals are unchanged.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import json,textwrap
p=Path('hillclimb/rounds/8');rows=json.loads((p/'inventory.json').read_text())['images'];rows.sort(key=lambda r:({'main':0,'instruction-helper-raster':1,'video-witness':2}.get(r.get('imageSet'),0),r['testIdentifier'],r['attachmentName']));out=p/'contact-sheets';out.mkdir(exist_ok=True);pages=[]
for offset in range(0,len(rows),12):
 selected=rows[offset:offset+12];canvas=Image.new('RGB',(1000,1560),'#ddd');draw=ImageDraw.Draw(canvas)
 for i,r in enumerate(selected):
  im=Image.open(p/r['file']).convert('RGB');im.thumbnail((240,450));x=i%4*250;y=i//4*520;canvas.paste(im,(x,y));name=r['attachmentName'].split('_0_')[0];label=r['testIdentifier'].split('/')[0]+'\n'+name
  draw.multiline_text((x+2,y+453),'\n'.join(textwrap.wrap(label,38))[:150],fill='black',spacing=2)
 dest=out/f'page-{offset//12+1:02}.jpg';canvas.save(dest,quality=90);pages.append(dict(file=str(dest),images=[r['file'] for r in selected]))
Path('hillclimb/validation/round8/contact-list.json').write_text(json.dumps(pages,indent=2)+'\n');print(len(rows),'images',len(pages),'pages')
