"""Verify regular native AX content once and centered native ink.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,json,hashlib,collections
from PIL import Image,ImageDraw
import numpy as np
p=pathlib.Path(__file__).parent;original=json.loads((p/'immutable-original.json').read_text())['original'];rows=[];proof=[]
def lum(c):
 a=np.array(c)/255;v=np.where(a<=.04045,a/12.92,((a+.055)/1.055)**2.4);return float(v@np.array([.2126,.7152,.0722]))
for size in ['default','XXXL']:
 for style in ['light','dark']:
  name=f'manual-{style}-{size}';f=p/(name+'-centered.png');d=json.loads((p/(name+'-ax.json')).read_text());assert d['success'];nodes=d['data']['nodes'];paragraphs=[next(n for n in nodes if n.get('identifier')==key) for key in ['account.guidance.activity','account.guidance.background']];labels=[n['label'] for n in paragraphs];assert ' '.join(labels)==original;assert all(sum(n.get('label')==label for n in nodes)==1 for label in labels);assert not any(n.get('label')==original for n in nodes)
  bar=next(n for n in nodes if n.get('kind')=='navigation-bar' and (n.get('label')=='Account' or n.get('identifier')=='Account'))['rect'];im=Image.open(f).convert('RGB');assert im.size==(1206,2622);ratios=[]
  for n in paragraphs:
   r=n['rect'];assert n['hittable'] and r['y']>=bar['y']+bar['height']+8 and r['y']+r['height']<=832
   a=np.asarray(im.crop((int(r['x']*3),int(r['y']*3),int((r['x']+r['width'])*3),int((r['y']+r['height'])*3))))
   same=np.all(a[:-1,:-1]==a[1:,:-1],axis=2)&np.all(a[:-1,:-1]==a[:-1,1:],axis=2)&np.all(a[:-1,:-1]==a[1:,1:],axis=2);colors=collections.Counter(map(tuple,a[:-1,:-1][same]));background=colors.most_common(1)[0][0];ink=max((c for c in colors if abs(lum(c)-lum(background))>.1),key=lambda c:colors[c]);ratio=(max(lum(ink),lum(background))+.05)/(min(lum(ink),lum(background))+.05);assert ratio>=7;ratios.append(ratio)
  first,second=[n['rect'] for n in paragraphs];gap=second['y']-first['y']-first['height'];assert abs(gap-6)<.5
  proof.append(dict(name=name,paragraphNodes=paragraphs,fullCopyOnce=True,spacing=gap,contrast=ratios));rows.append(dict(path=str(f),name=f.stem,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),dimensions=list(im.size),source='own pinned agent-device screenshot --pixel-density3'))
sheet=Image.new('RGB',(1000,610),'#ddd');draw=ImageDraw.Draw(sheet)
for i,r in enumerate(rows):
 im=Image.open(r['path']);im.thumbnail((245,550));sheet.paste(im,(i*250,40));draw.text((i*250,5),r['name'],fill='black')
sheet.save(p/'manual-contact.jpg');(p/'manual-images.json').write_text(json.dumps(rows,indent=2));(p/'manual-proof.json').write_text(json.dumps(proof,indent=2));print('4 native AX snapshots: exact labels once, safe guidance,6pt gap, minimum contrast',min(min(a['contrast']) for a in proof))
