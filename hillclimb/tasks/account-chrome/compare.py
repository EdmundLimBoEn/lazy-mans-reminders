"""Title-band native pixel comparison. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,re,sys,collections
from PIL import Image
import numpy as np
p=pathlib.Path(__file__).parent
records=[]
for phase in sys.argv[1:]:
 d=p/(phase+'-AccountChromeUITests');manifest=json.loads((d/'manifest.json').read_text());attachments=[a for t in manifest for a in t['attachments']]
 for row in json.loads((p/(phase+'-images.json')).read_text()):
  name=row['name']
  if 'scrolled' not in name:continue
  geom=next(a for a in attachments if a.get('suggestedHumanReadableName','').startswith(name+'-geometry_'))
  text=(d/geom['exportedFileName']).read_text();f=list(map(float,re.search(r'title=\(([^)]+)\)',text).group(1).split(',')))
  im=Image.open(row['path']).convert('RGB');scale=im.width/402
  # Left of the actual title, inside the sheet: excludes title, Done, grabber and rounded edge.
  roi=(int(28*scale),int(f[1]*scale),int((f[0]-12)*scale),int((f[1]+f[3])*scale))
  a=np.asarray(im.crop(roi))/255;lin=np.where(a<=.04045,a/12.92,((a+.055)/1.055)**2.4);lum=lin@np.array([.2126,.7152,.0722]);bg=np.median(lum,axis=1)[:,None];ratios=(np.maximum(lum,bg)+.05)/(np.minimum(lum,bg)+.05)
  records.append(dict(phase=phase,name=name,roi=roi,maximum=float(ratios.max()),over1_5=int((ratios>1.5).sum()),pixels=ratios.size))
(p/'title-comparison.json').write_text(json.dumps(records,indent=2));print(json.dumps(records,indent=2))
