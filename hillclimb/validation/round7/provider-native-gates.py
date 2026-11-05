"""Enabled provider ink and neutral field distinction in untouched native PNGs.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from PIL import Image
from collections import Counter
import json,hashlib
p=Path(__file__).parent;t=Path('hillclimb/tasks/login-composition');rows=[]
def lum(rgb):
 c=[v/255 for v in rgb];c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
 return sum(a*b for a,b in zip(c,[.2126,.7152,.0722]))
files=list((t/'after-complete').glob('*enabled-default.png'))+list(Path('hillclimb/rounds/7/signin-paint/combined').glob('*-default-empty.png'))
for file in sorted(files):
 nodes=json.loads(file.with_suffix('.json').read_text())['data']['nodes'];im=Image.open(file).convert('RGB');record=dict(file=str(file),sha256=hashlib.sha256(file.read_bytes()).hexdigest(),providers=[])
 for label in ['Sign in with Apple','Sign in with Google']:
  node=next(n for n in nodes if n.get('label')==label and n.get('type')=='Button');assert node['enabled'];f=node['rect'];assert f['height']+1e-9>=48
  crop=im.crop(tuple(round(v*3) for v in [f['x']+20,f['y']+5,f['x']+f['width']-20,f['y']+f['height']-5]));hist=Counter(crop.get_flattened_data());bg=hist.most_common(1)[0][0];ink=max(((rgb,count) for rgb,count in hist.items() if max(rgb)-min(rgb)<10 and abs(lum(rgb)-lum(bg))>.2),key=lambda x:x[1]);a,b=sorted([lum(bg),lum(ink[0])]);ratio=(b+.05)/(a+.05);assert ratio>=4.5 and ink[1]>500
  if label.endswith('Apple'):assert node['role']=='ASAuthorizationAppleIDButton'
  record['providers'].append(dict(label=label,role=node['role'],frame=f,backgroundRGB=bg,solidGlyphRGB=ink[0],glyphPixels=ink[1],contrast=ratio))
 google=record['providers'][1];field=next(n for n in nodes if n.get('type')=='TextField' and n.get('label')=='Email address');f=field['rect'];fieldRGB=im.getpixel((round((f['x']+f['width']-20)*3),round((f['y']+f['height']/2)*3)));assert max(fieldRGB)-min(fieldRGB)<10;assert sum(abs(a-b) for a,b in zip(fieldRGB,google['backgroundRGB']))>15
 record.update(fieldFrame=f,neutralFieldRGB=fieldRGB,googleDistinctFromField=True);rows.append(record)
assert len(rows)==8
(p/'provider-native-gates.json').write_text(json.dumps(dict(samples=rows,allPassed=True,minimumContrast=min(x['contrast'] for r in rows for x in r['providers']),sourceIdentity=json.loads((t/'freeze.json').read_text())['sourceIdentity']),indent=2))
print('16 native enabled provider samples retain glyphs, framework Apple role and4.5:1 contrast, normal+combined; Google differs from filled field')
