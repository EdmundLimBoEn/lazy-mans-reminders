import sys
finalPhase=sys.argv[1] if len(sys.argv)>1 else "full"
"""Match native content targets; do not mistake swipe offsets for progress.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
p=Path(__file__).parent;old={r['name']:r for r in json.loads((p/'before-images.json').read_text())};new={r['name']:r for r in json.loads((p/(finalPhase+'-images.json')).read_text())};rows=[]
for name in old.keys()&new.keys():
 style,size=name.split('-')[:2]
 ref='hillclimb/reference/'+(('round3/reminders-sheet-'+style+'-XXXL.png') if size=='XXXL' else ('round2/reminders-sheet-light.png' if style=='light' else 'reminders-sheet-dark.png'))
 match=any(name.endswith(s) for s in ['large-top','medium-top','large-guidance','medium-guidance','-error','-recovered'])
 rows.append(dict(name=name,before=old[name],after=new[name],matchedContentTarget=match,positionScope='same initial/resting top or full guidance target; identical fixture/style/size/detent' if match else 'same gesture protocol; absolute content positions may differ, excluded from density-improvement claim',Apple={'path':ref,'sha256':hashlib.sha256(Path(ref).read_bytes()).hexdigest(),'gaps':['Item Details has different semantics and shorter prose','No medium-detent Apple reference','No combined-settings exact reference']}))
rows.sort(key=lambda r:r['name']);matched=[r for r in rows if r['matchedContentTarget']];assert len(matched)==24
for i in range(0,len(matched),3):
 sheet=Image.new('RGB',(1500,590),'#dddddd');draw=ImageDraw.Draw(sheet)
 for j,r in enumerate(matched[i:i+3]):
  for k,phase in enumerate(['before','after']):
   im=Image.open(r[phase]['path']);im.thumbnail((240,535));x=(j*2+k)*250;sheet.paste(im,(x,40));draw.text((x+2,2),r['name']+' '+phase,fill='black')
 sheet.save(p/('matched-%02d.jpg'%(i//3+1)))
(p/'pairings.json').write_text(json.dumps({'matchedDensityPairs':24,'otherSafetyPairs':len(rows)-24,'pairs':rows},indent=2))
print('24 matched resting/guidance/recovery pairs; others safety only')
