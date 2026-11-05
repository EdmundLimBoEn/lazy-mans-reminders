"""Native raster span, preserving raw fractional AX values. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
import json,re,ast
from PIL import Image
p=Path(__file__).parent;d=p/'combined-SignInChromeUITests';rows=[]
for test in json.loads((d/'manifest.json').read_text()):
 for a in test['attachments']:
  name=a['suggestedHumanReadableName'];f=d/a['exportedFileName']
  if not (name.startswith('chrome-password-') and '-geometry' in name):continue
  text=f.read_text();frame=ast.literal_eval(re.search(r'field=(\([^)]*\))',text.splitlines()[0]).group(1))
  base=name.split('_0_')[0].removesuffix('-geometry')
  shot=next(x for x in test['attachments'] if x['suggestedHumanReadableName'].startswith(base+'_0_') and x['exportedFileName'].endswith('.png'))
  im=Image.open(d/shot['exportedFileName']).convert('RGB');assert im.size==(1206,2622)
  x=round((frame[0]+frame[2]/2)*3);top=round(frame[1]*3);bottom=round((frame[1]+frame[3])*3);color=im.getpixel((x,(top+bottom)//2))
  y=(top+bottom)//2
  while y>0 and im.getpixel((x,y-1))==color:y-=1
  end=(top+bottom)//2
  while end+1<im.height and im.getpixel((x,end+1))==color:end+=1
  rows.append(dict(name=base,rawAXFrame=frame,AXTopPixel=top,AXBottomPixel=bottom,rasterTop=y,rasterBottomExclusive=end+1,rasterHeight=end+1-y,nativePointHeight=(end+1-y)/3,centerRGB=color))
assert len(rows)==16
(p/'secure-field-pixel-proof.json').write_text(json.dumps(rows,indent=2));print([(r['name'],r['rasterHeight']) for r in rows])
assert all(r['rasterHeight']>=144 and r['rasterTop']==r['AXTopPixel'] and r['rasterBottomExclusive']==r['AXBottomPixel'] for r in rows)
