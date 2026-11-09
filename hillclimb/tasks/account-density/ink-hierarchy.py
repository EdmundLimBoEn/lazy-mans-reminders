import sys
finalPhase=sys.argv[1] if len(sys.argv)>1 else "full"
"""Compare native helper and action ink from the same settled image.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from PIL import Image
from collections import Counter
import numpy as np,json,re
p=Path(__file__).parent;rows=[]
def luminance(c):
 a=np.array(c)/255;v=np.where(a<=.04045,a/12.92,((a+.055)/1.055)**2.4);return float(v@np.array([.2126,.7152,.0722]))
def ink(im,f):
 x,y,w,h=f;a=np.asarray(im.crop((round(x*3),round(y*3),round((x+w)*3),round((y+h)*3))))
 same=np.all(a[:-1,:-1]==a[1:,:-1],axis=2)&np.all(a[:-1,:-1]==a[:-1,1:],axis=2)&np.all(a[:-1,:-1]==a[1:,1:],axis=2)
 colors=Counter(map(tuple,a[:-1,:-1][same]));bg=colors.most_common(1)[0][0];fg=max((c for c in colors if abs(luminance(c)-luminance(bg))>.1),key=colors.get)
 ratio=(max(luminance(fg),luminance(bg))+.05)/(min(luminance(fg),luminance(bg))+.05)
 return dict(background=list(map(int,bg)),foreground=list(map(int,fg)),contrast=ratio)
for phase in ['before',finalPhase]:
 d=p/(phase+'-AccountChromeUITests');m=json.loads((d/'manifest.json').read_text());ats=[a for t in m for a in t['attachments']]
 for a in ats:
  name=a.get('suggestedHumanReadableName','')
  if not any(name.startswith(style+'-default-large-guidance-proof_') for style in ['light','dark']):continue
  text=(d/a['exportedFileName']).read_text();frames={k:list(map(float,v.split(','))) for k,v in re.findall(r'"([^"]+)": \[([^\]]+)\]',text)}
  base=name.split('-proof_')[0];shot=next(b for b in ats if b.get('suggestedHumanReadableName','').startswith(base+'_') and b['exportedFileName'].endswith('.png'));im=Image.open(d/shot['exportedFileName']).convert('RGB')
  action=ink(im,frames['refresh.title']);helper=ink(im,frames['persistence.activity']);assert action['contrast']>=7 and helper['contrast']>=7
  if phase!='before':assert action['contrast']>helper['contrast']+2
  rows.append(dict(phase=phase,name=base,action=action,guidance=helper))
assert len(rows)==4
(p/'ink-hierarchy.json').write_text(json.dumps(rows,indent=2));print(json.dumps(rows,indent=2))
