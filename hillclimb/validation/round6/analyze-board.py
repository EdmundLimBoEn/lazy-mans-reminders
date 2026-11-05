"""Full-coverage native glyph contrast and final-row geometry evidence.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
from PIL import Image
from collections import Counter
from pathlib import Path
import json,hashlib
O=Path(__file__).parent;C=Path('hillclimb/rounds/6/board');m=json.loads((C/'manifest.json').read_text());results=[]
def lum(rgb):
 c=[x/255 for x in rgb];c=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in c]
 return sum(a*b for a,b in zip(c,[.2126,.7152,.0722]))
for capture in m['captures']:
 f=C/capture['file'];assert hashlib.sha256(f.read_bytes()).hexdigest()==capture['sha256']
 if '-top.png' not in f.name and '-true-bottom-after-pull.png' not in f.name:continue
 g=json.loads(f.with_suffix('.geometry.json').read_text());im=Image.open(f).convert('RGB');scale=im.width/402
 r={'file':f.name,'regions':{}}
 for key in ['capacity','capacityHint']:
  x,y,w,h=g[key];box=tuple(round(v*scale) for v in [x,y,x+w,y+h]);hist=Counter(im.crop(box).get_flattened_data());bg=hist.most_common(1)[0][0];bgL=lum(bg)
  ink,n=max(((color,count) for color,count in hist.items() if abs(lum(color)-bgL)>.2),key=lambda p:p[1]);fgL=lum(ink);contrast=(max(fgL,bgL)+.05)/(min(fgL,bgL)+.05)
  assert n>20 and contrast>=4.5,(f.name,key,ink,bg,contrast)
  r['regions'][key]={'boxPx':box,'backgroundRGB':bg,'solidGlyphRGB':ink,'solidGlyphPixels':n,'contrast':contrast}
 if '-true-bottom-after-pull.png' in f.name:
  last=g['00000000-0000-4000-8000-000000000007'];text=g['text-00000000-0000-4000-8000-000000000007'];viewport=g['listViewport'];composer=g['composer'];fade=g['bottomFade']
  assert last[1]>=viewport[1] and last[1]+last[3]<=composer[1]+.5
  assert text[1]+text[3]<=min(composer[1],fade[1])+.5
  r['finalRow']={'row':last,'text':text,'viewport':viewport,'composer':composer,'bottomFade':fade}
 results.append(r)
(O/'pixel-geometry-results.json').write_text(json.dumps(results,indent=2)+'\n');print(len(results),'native board measurements passed')
