"""Measure unmodified native PNGs using same-capture accessibility rectangles.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
from pathlib import Path
from PIL import Image
from collections import Counter
import json,math,hashlib
p=Path(__file__).parent
report={'normalText':[],'apple':[],'keyboard':[]}
texts=['Notepad','Your board on this iPhone, the web, and the Lock Screen.','Use the same address as the web board.','For an existing account with a password. You can also use a sign-in link.','We sent a sign-in link to you@example.com.']
def crop(image,r):
 s=image.width/402
 return image.crop(tuple(round(v*s) for v in [r['x'],r['y'],r['x']+r['width'],r['y']+r['height']])).convert('RGB')
def lum(rgb):
 c=[v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb]
 return sum(a*b for a,b in zip(c,[.2126,.7152,.0722]))
for folder in ['surfaces','captures']:
 for f in sorted((p/folder).glob('*-geometry.json')):
  name=f.name.removesuffix('-geometry.json');nodes=json.loads(f.read_text())['data']['nodes'];image=Image.open(f.with_name(name+'.png'));dark='-dark-' in name
  for node in nodes:
   label=node.get('label','');r=node['rect']
   if label in texts and node.get('kind')=='text' and r['y']>=168 and r['y']+r['height']<=840:
    counts=Counter(crop(image,r).getdata());bg=(0,0,0) if dark else (255,255,255)
    ink,count=max(((rgb,count) for rgb,count in counts.items() if all(abs(a-b)>40 for a,b in zip(rgb,bg))),key=lambda x:x[1]);ratio=(max(lum(ink),lum(bg))+.05)/(min(lum(ink),lum(bg))+.05)
    assert ratio>=4.5,(name,label,ink,ratio)
    report['normalText'].append({'capture':name,'text':label,'solidInk':ink,'background':bg,'count':count,'contrast':ratio})
   if node.get('identifier')=='signin.apple' and dark:
    strip=dict(x=r['x']+6,y=r['y']+8,width=8,height=r['height']-16);samples=list(crop(image,strip).getdata());fraction=sum(max(rgb)>20 for rgb in samples)/len(samples)
    assert fraction>.8,(name,fraction)
    report['apple'].append({'capture':name,'enabled':node['enabled'],'stripNonBlackFraction':fraction,'rect':r})
  if folder=='captures':
   def get(label=None,kind=None):return next(n['rect'] for n in nodes if (label is None or n.get('label')==label) and (kind is None or n.get('kind')==kind))
   done=get('Done');alternate=get('Use a Sign-In Link Instead' if 'password-keyboard' in name else 'Use an Existing Password');keyboard=get(kind='keyboard')
   clearance=done['y']-(alternate['y']+alternate['height']);gap=keyboard['y']-done['y']-done['height']
   assert done['height']>=48 and done['width']>=48 and clearance>=8 and gap>=0,(name,done,clearance,gap)
   report['keyboard'].append({'capture':name,'Done':done,'alternate':alternate,'keyboard':keyboard,'alternateClearance':clearance,'DoneToKeyboardGap':gap})
assert len(report['keyboard'])==8
assert len(report['apple'])>=4
report['pngHashes']={str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest() for folder in ['surfaces','captures','pixel-test-native'] for f in (p/folder).glob('*.png')}
(p/'native-measurements.json').write_text(json.dumps(report,indent=2))
print({k:len(v) for k,v in report.items()})
