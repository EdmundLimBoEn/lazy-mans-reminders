"""Measure instruction-only interiors in inspected native guide originals.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
from pathlib import Path
from collections import Counter
from PIL import Image
import json
O=Path(__file__).parent;results=[]
def lum(rgb):
 c=[x/255 for x in rgb];c=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in c]
 return sum(a*b for a,b in zip(c,[.2126,.7152,.0722]))
for style in ['light','dark']:
 for size in ['default','XXXL']:
  f=O/'captures'/f'{style}-{size}-guide.png'
  # Pixel crop selected from the native originals: instruction text to the
  # right of the symbols, below the guide heading, above the composer.
  box=(200,1250,1110,1990)
  hist=Counter(Image.open(f).convert('RGB').crop(box).get_flattened_data());bg=hist.most_common(1)[0][0];b=lum(bg)
  ink,n=max(((c,n) for c,n in hist.items() if abs(lum(c)-b)>.2),key=lambda p:p[1]);i=lum(ink);contrast=(max(i,b)+.05)/(min(i,b)+.05)
  assert n>100 and contrast>=4.5
  results.append({'file':f.name,'boxPx':box,'backgroundRGB':bg,'solidGlyphRGB':ink,'solidGlyphPixels':n,'contrast':contrast})
(O/'guide-contrast-results.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2))
