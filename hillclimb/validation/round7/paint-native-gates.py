"""Native enabled-action color/semantics from original PNGs and paired AX snapshots.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from PIL import Image
from collections import Counter
import json,hashlib
p=Path(__file__).parent;t=Path('hillclimb/tasks/login-composition');rows=[]
def luminance(rgb):
 c=[v/255 for v in rgb];c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c];return sum(a*b for a,b in zip(c,[.2126,.7152,.0722]))
files=list((t/'after-complete').glob('*filled-*.png'))+list(Path('hillclimb/rounds/7/signin-paint/combined').glob('*-filled.png'))
for file in files:
 tree=json.loads(file.with_suffix('.json').read_text());nodes=tree['data']['nodes'];button=next(n for n in nodes if n.get('type')=='Button' and n.get('label') in ['Send Sign-In Link','Sign In with Password']);assert button['enabled'];frame=button['rect'];im=Image.open(file).convert('RGB');box=tuple(round(v*3) for v in [frame['x']+16,frame['y']+5,frame['x']+frame['width']-16,frame['y']+frame['height']-5]);hist=Counter(im.crop(box).get_flattened_data());background=hist.most_common(1)[0][0];bg=luminance(background);ink=max(((rgb,count) for rgb,count in hist.items() if max(rgb)-min(rgb)<10 and abs(luminance(rgb)-bg)>.05),key=lambda x:x[1]);fg=luminance(ink[0]);ratio=(max(bg,fg)+.05)/(min(bg,fg)+.05);assert ratio>=4.5 and ink[1]>100;rows.append(dict(file=str(file),sha256=hashlib.sha256(file.read_bytes()).hexdigest(),frame=frame,backgroundRGB=background,solidGlyphRGB=ink[0],glyphPixels=ink[1],contrast=ratio,configuration='Actual combined system flags' if '/combined/' in str(file) else 'Original switches; app-local appearance/type override'))
assert len(rows)==16,len(rows)
legal=[]
for file in sorted(Path('hillclimb/rounds/7/signin-paint').glob('*/*-bottom.png')):
 nodes=json.loads(file.with_suffix('.json').read_text())['data']['nodes'];im=Image.open(file).convert('RGB')
 for label in ['Privacy','Terms','Support']:
  node=next(n for n in nodes if n.get('type')=='Link' and n.get('label')==label);f=node['rect'];clearance=840-f['y']-f['height'];assert clearance>=8
  box=tuple(round(v*3) for v in [f['x'],f['y'],f['x']+f['width'],f['y']+f['height']]);hist=Counter(im.crop(box).get_flattened_data());bg=hist.most_common(1)[0][0];ink=max(((rgb,count) for rgb,count in hist.items() if max(rgb)-min(rgb)<10 and abs(luminance(rgb)-luminance(bg))>.2),key=lambda x:x[1]);a,b=sorted([luminance(bg),luminance(ink[0])]);contrast=(b+.05)/(a+.05);assert contrast>=4.5 and ink[1]>100
  legal.append(dict(file=str(file),label=label,frame=f,safeBottom=840,safeBottomSource='Native full-scheme gesture geometry on same original17 portrait device',clearance=clearance,solidGlyphPixels=ink[1],contrast=contrast,position='Explicit inert bottom argument; no manual gesture'))
assert len(legal)==24
empty=[]
for file in list((t/'after-complete').glob('*enabled-*.json'))+list(Path('hillclimb/rounds/7/signin-paint').glob('*/*.json')):
 if file.name=='manifest.json' or 'filled' in file.name:continue
 tree=json.loads(file.read_text());nodes=tree['data']['nodes'];button=next(n for n in nodes if n.get('type')=='Button' and n.get('label') in ['Send Sign-In Link','Sign In with Password']);assert not button['enabled'];empty.append(str(file))
assert len(empty)==24
(p/'paint-native-gates.json').write_text(json.dumps(dict(samples=rows,minimumContrast=min(r['contrast'] for r in rows),threshold=4.5,legal=legal,minimumExplicitPaintLegalClearance=min(r['clearance'] for r in legal),emptyDisabledSamples=empty,allPassed=True,sourceIdentity=json.loads((t/'freeze.json').read_text())['sourceIdentity']),indent=2));print('16 native filled actions pass4.5:1;24empty states remain disabled;8explicit bottom paints retain all3legal labels and>=8pt clearance')
