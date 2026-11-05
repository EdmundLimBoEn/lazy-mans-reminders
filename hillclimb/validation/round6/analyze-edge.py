"""Native raster gates; no unit renders or derived images. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
from PIL import Image
from collections import Counter
import json,re,hashlib
p=Path('hillclimb/rounds/6/edge'); captures=p/'captures'
def lum(rgb):
 c=[v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4 for v in rgb[:3]]
 return sum(a*b for a,b in zip(c,[.2126,.7152,.0722]))
def contrast(rgb,dark):
 l=lum(rgb);return (l+.05)/.05 if dark else 1.05/(l+.05)
results=[]
for f in sorted(p.glob('captures*/*.png')):
 meta=f.with_suffix('.json')
 if not meta.exists(): continue
 m=json.loads(meta.read_text());g=m['geometry'];dark=m['dark'];im=Image.open(f).convert('RGB');scale=im.width/402
 record={'file':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'size':im.size,'scale':scale}
 if m['kind'] in ['bottom','partial']:
  x,y,w,h=g['listViewport'];box=(round((x+68)*scale),round(y*scale),round((x+w-60)*scale),round(y*scale)+14)
  counts=Counter(im.crop(box).get_flattened_data());record['topBandBox']=box;record['above3']=sum(n for rgb,n in counts.items() if contrast(rgb,dark)>3)
  record['topBandMaximumContrast']=max(contrast(rgb,dark) for rgb in counts)
  assert record['above3']==0,record
 if m['kind']=='bottom':
  text=g['text-00000000-0000-4000-8000-000000000007'];row=g['00000000-0000-4000-8000-000000000007'];v=g['listViewport'];composer=g['composer'];fade=g['bottomFade']
  assert row[1]>=v[1]-.5 and row[1]+row[3]<=composer[1]+.5,(f,row,v,composer)
  assert text[1]+text[3]<=min(composer[1],fade[1])+.5,(f,text,composer,fade)
  x,y,w,h=text;crop=im.crop((round(x*scale),round((y+h-18)*scale),round((x+w)*scale),round((y+h-2)*scale)))
  strong=sum(min(rgb)>200 if dark else max(rgb)<55 for rgb in crop.get_flattened_data());assert strong>20,(f,strong);record['finalLineStrongPixels']=strong;record['bottomRowClearsComposer']=True
 if m['kind']=='top':
  text=g['text-00000000-0000-4000-8000-000000000001'];ideal=g['ideal-00000000-0000-4000-8000-000000000001'];v=g['listViewport'];assert text[1]>=v[1] and text[1]+text[3]<=g['composer'][1]+.5,(f,text,v)
  assert text[3]+.5>=ideal[3],(f,text,ideal)
  x,y,w,h=text;counts=Counter(im.crop((round(x*scale),round(y*scale),round((x+w)*scale),round((y+h)*scale))).get_flattened_data());ink,n=max(((rgb,n) for rgb,n in counts.items() if contrast(rgb,dark)>2),key=lambda pair:pair[1]);assert contrast(ink,dark)>=4.5 and n>20;record['freshTopFirstRowContrast']=contrast(ink,dark)
 if m['kind']=='diagnostic':
  x,y,w,h=g[m['probe']];counts=Counter(im.crop((round(x*scale),round(y*scale),round((x+w)*scale),round((y+h)*scale))).get_flattened_data())
  ink,n=max(((rgb,n) for rgb,n in counts.items() if contrast(rgb,dark)>2),key=lambda pair:pair[1]);record.update(ink=ink,inkPixels=n,contrast=contrast(ink,dark));assert n>20 and record['contrast']>=4.5,record
 results.append(record)
(p/'raster-results.json').write_text(json.dumps(results,indent=2));print('Native gates:',len(results))
