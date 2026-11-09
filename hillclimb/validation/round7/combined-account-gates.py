"""Actual combined-settings persistence guidance from native pixels.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from PIL import Image
from collections import Counter
import json,re,hashlib,math
p=Path(__file__).parent;root=Path('.');out=Path('hillclimb/rounds/7/account-combined');rows=[]
def frames(obj):
 if isinstance(obj,dict):
  for k,v in obj.items():
   if k=='value' and isinstance(v,str):
    try:
     x=json.loads(v)
     if isinstance(x,dict) and 'persistence.footer' in x:return x
    except (ValueError,TypeError):
     x={k:json.loads('['+a+']') for k,a in re.findall(r'"([^"\\]+)":\[([^\]]+)\]',v)}
     if 'persistence.footer' in x:return x
   found=frames(v)
   if found:return found
 elif isinstance(obj,list):
  for v in obj:
   found=frames(v)
   if found:return found
def lum(rgb):
 c=[v/255 for v in rgb];c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c];return sum(a*b for a,b in zip(c,[.2126,.7152,.0722]))
for capture in json.loads((out/'captures-guidance.json').read_text())['images']:
 file=Path(capture['path']);assert hashlib.sha256(file.read_bytes()).hexdigest()==capture['sha256'];f=frames(json.loads(capture['geometry']))['persistence.footer'];x,y,w,h=f;assert y>170 and y+h<840
 im=Image.open(file).convert('RGB');hist=Counter(im.crop((math.ceil(x*3),math.ceil(y*3),math.floor((x+w)*3),math.floor((y+h)*3))).get_flattened_data());bg=hist.most_common(1)[0][0];ink=max(((rgb,count) for rgb,count in hist.items() if max(rgb)-min(rgb)<12 and abs(lum(rgb)-lum(bg))>.25),key=lambda x:x[1]);a,b=sorted([lum(bg),lum(ink[0])]);ratio=(b+.05)/(a+.05);assert ratio>=7 and ink[1]>100
 rows.append(dict(file=str(file),sha256=capture['sha256'],frame=f,backgroundRGB=bg,solidGlyphRGB=ink[0],solidPixels=ink[1],contrast=ratio,settings='manual-enabled.json'))
assert len(rows)==4
(p/'combined-account-gates.json').write_text(json.dumps(dict(samples=rows,minimumContrast=min(r['contrast'] for r in rows),threshold=7,allPassed=True),indent=2));print('4 actual combined-settings Account persistence samples pass7:1')
