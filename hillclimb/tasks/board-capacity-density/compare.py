"""Compare matched native before/after pixels and actual geometry.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from collections import Counter
from PIL import Image,ImageDraw
import json,hashlib,re,sys
p=Path(__file__).parent;run=sys.argv[1];rows=[]
def lum(rgb):
 c=[v/255 for v in rgb];c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
 return sum(a*b for a,b in zip(c,[.2126,.7152,.0722]))
for f in sorted((p/(run+'-captures')).glob('*.png')):
 before=p/'baseline-captures'/f.name;g=json.loads(f.with_suffix('.geometry.json').read_text());b=json.loads(before.with_suffix('.geometry.json').read_text());im=Image.open(f).convert('RGB');assert im.size==(1206,2622)
 row=dict(file=str(f),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),before=str(before),beforeSHA256=hashlib.sha256(before.read_bytes()).hexdigest(),dimensions=im.size,composerBefore=b['composer'],composerAfter=g['composer'])
 if any(s in f.name for s in ['full-top','bottom-after-pull']):
  assert g['composer'][3]<=b['composer'][3];row['heightSaved']=b['composer'][3]-g['composer'][3];row['regions']={}
  for key in ['capacity','capacityHint']:
   x,y,w,h=g[key];hist=Counter(im.crop(tuple(round(v*3) for v in [x,y,x+w,y+h])).get_flattened_data());bg=hist.most_common(1)[0][0];bl=lum(bg);ink,n=max(((c,n) for c,n in hist.items() if abs(lum(c)-bl)>.2),key=lambda q:q[1]);ratio=(max(lum(ink),bl)+.05)/(min(lum(ink),bl)+.05);assert n>20 and ratio>=4.5
   row['regions'][key]=dict(frame=g[key],inkRGB=ink,backgroundRGB=bg,solidInkPixels=n,contrast=ratio)
  ax=f.with_suffix('.ax.txt').read_text();line=next(l for l in ax.splitlines() if "identifier: 'board.capacity'" in l);coords=[float(n) for n in re.search(r'\{\{([^}]+)\}, \{([^}]+)\}\}',line).group(0).replace('{','').replace('}','').split(',')];assert coords[0]==18 and coords[2]==366 and coords[3]>=44
  hint=g['capacityHint'];gap=round(hint[1]-coords[1]-coords[3],1);assert 6<=gap<=8;assert abs(coords[0]-hint[0])<=1;row.update(statusAXFrame=coords,gap=gap)
  assert g['capacity'][3]+.5>=g['capacityIdeal'][3]
  # Typography and row measure must remain identical at matched natural top/bottom states.
  for key in ['capacity', 'capacityHint']:
   assert abs(g[key][3]-b[key][3])<.01
  rid='00000000-0000-4000-8000-000000000007' if 'bottom-after-pull' in f.name else '00000000-0000-4000-8000-000000000001'
  for key in [rid,'text-'+rid]:
   assert all(abs(a-bb)<.01 for a,bb in zip(g[key][2:],b[key][2:]))
  if 'bottom-after-pull' in f.name:
   rid='00000000-0000-4000-8000-000000000007';r=g[rid];t=g['text-'+rid];assert r[1]>=g['listViewport'][1] and r[1]+r[3]<=g['composer'][1]+.5
   x,y,w,h=t;band=im.crop(tuple(round(v*3) for v in [x,y+h-18,x+w,y+h-2]));strong=sum(min(c)>200 if '-dark-' in f.name else max(c)<55 for c in band.get_flattened_data());assert strong>20;row['strongFinalInkPixels']=strong
 else:
  assert all(abs(a-bb)<.5 for a,bb in zip(g['composer'],b['composer']))
 rows.append(row)
assert len(rows)==16
(p/(run+'-comparison.json')).write_text(json.dumps(rows,indent=2))
for state in ['full-top','bottom-after-pull','below-capacity','normal-composer-draft']:
 sheet=Image.new('RGB',(1200,1400),'#888888');draw=ImageDraw.Draw(sheet)
 for i,(style,size) in enumerate((s,z) for s in ['light','dark'] for z in ['default','XXXL']):
  for j,phase in enumerate(['baseline',run]):
   f=p/(phase+'-captures')/f'capacity-{style}-{size}-{state}.png';image=Image.open(f);image.thumbnail((295,650));x=i%2*600+j*300;y=i//2*700;sheet.paste(image,(x,y+25));draw.text((x+5,y+5),f'{phase} {style} {size}',fill='white')
 sheet.save(p/(run+'-'+state+'-contact.jpg'),quality=90)
print('16 matched native pairs; all geometry/contrast/height checks pass')
