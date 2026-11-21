"""Native capacity pixels and geometry; no unit render substitutes.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from collections import Counter
from PIL import Image
import json,sys,re
p=Path(__file__).parent;run=sys.argv[1];out=[]
def lum(rgb):
 c=[v/255 for v in rgb];c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
 return sum(a*b for a,b in zip(c,[.2126,.7152,.0722]))
for f in sorted((p/(run+'-captures')).glob('*.png')):
 if not any(s in f.name for s in ['full-top','bottom-after-pull']):continue
 g=json.loads(f.with_suffix('.geometry.json').read_text());im=Image.open(f).convert('RGB');scale=im.width/402;r=dict(image=str(f),regions={})
 for key in ['capacity','capacityHint']:
  x,y,w,h=g[key];hist=Counter(im.crop(tuple(round(v*scale) for v in [x,y,x+w,y+h])).get_flattened_data());bg=hist.most_common(1)[0][0];bl=lum(bg)
  ink,n=max(((c,n) for c,n in hist.items() if abs(lum(c)-bl)>.2),key=lambda q:q[1]);fl=lum(ink);ratio=(max(fl,bl)+.05)/(min(fl,bl)+.05)
  assert n>20 and ratio>=4.5
  r['regions'][key]=dict(frame=g[key],inkRGB=ink,backgroundRGB=bg,solidInkPixels=n,contrast=ratio)
 assert g['capacity'][3]+.5>=g['capacityIdeal'][3]
 ax=f.with_suffix('.ax.txt').read_text();line=next(l for l in ax.splitlines() if "identifier: 'board.capacity'" in l)
 coords=[float(n) for n in re.search(r'\{\{([^}]+)\}, \{([^}]+)\}\}',line).group(0).replace('{','').replace('}','').split(',')]
 assert coords[0]==30 and coords[2]==351 and coords[3]>=44
 assert "label: 'Board full — combine lines instead'" in line
 assert "label: 'Add reminder'" not in ax and "label: 'Adding reminder'" not in ax
 r['statusAXFrame']=coords
 if 'bottom-after-pull' in f.name:
  row=g['00000000-0000-4000-8000-000000000007'];text=g['text-00000000-0000-4000-8000-000000000007'];composer=g['composer'];viewport=g['listViewport']
  assert row[1]>=viewport[1] and row[1]+row[3]<=composer[1]+.5
  x,y,w,h=text;band=im.crop(tuple(round(v*scale) for v in [x,y+h-18,x+w,y+h-2]));dark='-dark-' in f.name
  strong=sum(1 for c in band.get_flattened_data() if (min(c)>200 if dark else max(c)<55));assert strong>20
  r['finalRow']=dict(row=row,text=text,composer=composer,viewport=viewport,strongFinalInkPixels=strong)
 out.append(r)
assert len(out)==8
(p/(run+'-pixel-geometry.json')).write_text(json.dumps(out,indent=2));print('8 native capacity/top/bottom geometry and pixel checks passed')
