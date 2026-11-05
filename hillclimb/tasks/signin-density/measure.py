"""Native AX/raster comparison, not source-only geometry. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
from PIL import Image
from collections import Counter
import json
p=Path(__file__).parent;rows=[]
for style in ['light','dark']:
 for size in ['default','XXXL']:
  pair={}
  for phase in ['before','after']:
   d=p/(phase+'-complete');name=f'{style}-{size}-password';j=json.loads((d/(name+'.json')).read_text());nodes=j['data']['nodes']
   def node(label):return next(n for n in nodes if n.get('label')==label)
   def rect(label):return node(label)['rect']
   def maxy(r):return r['y']+r['height']
   heading=rect('Email');helper=rect('Use the same address as the web board.');field=rect('Email address');password=rect('Password');hint=rect('For an existing account with a password. You can also use a sign-in link.')
   internal=8 if phase=='after' else 12
   label={'x':20,'y':password['y']-internal-heading['height'],'width':150,'height':heading['height']}
   im=Image.open(d/(name+'.png')).convert('RGB');assert im.size==(1206,2622)
   def pixels(r):return list(im.crop(tuple(round(v*3) for v in (r['x'],r['y'],r['x']+r['width'],r['y']+r['height']))).get_flattened_data())
   ink=lambda r:sum(all(v<80 for v in px) if style=='light' else all(v>180 for v in px) for px in pixels(r))
   labelInk=ink(label);assert labelInk>100,(phase,style,size,labelInk)
   counts=Counter(px for px in pixels(helper) if all(v<210 for v in px) if style=='light') if style=='light' else Counter(px for px in pixels(helper) if all(v>45 for v in px))
   rgb,n=counts.most_common(1)[0]
   def linear(v):
    s=v/255;return s/12.92 if s<=0.04045 else ((s+.055)/1.055)**2.4
   lum=sum(a*linear(v) for a,v in zip([.2126,.7152,.0722],rgb));contrast=1.05/(lum+.05) if style=='light' else (lum+.05)/.05
   assert contrast>=7 and n>20
   pair[phase]=dict(emailHeadingToHelper=helper['y']-maxy(heading),emailHelperToField=field['y']-maxy(helper),passwordFieldToHelper=hint['y']-maxy(password),passwordHeadingRasterRegion=label,passwordHeadingNativeInkPixels=labelInk,helperModalInkRGB=rgb,helperContrast=contrast)
  rows.append(dict(style=style,size=size,**pair))
(p/'before-after-measurements.json').write_text(json.dumps(rows,indent=2));print(json.dumps(rows,indent=2))
