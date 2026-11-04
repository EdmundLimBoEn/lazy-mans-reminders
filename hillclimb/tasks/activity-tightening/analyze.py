"""Native OCR + raster safety gates. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,subprocess,re,sys
from PIL import Image
p=pathlib.Path(__file__).parent/sys.argv[1]; results=[]
for file in sorted(p.glob('*.png')):
 if not any(t in file.name for t in ['expanded','notification-center']):continue
 rows=json.loads(subprocess.check_output(['/tmp/activity-tightening-ocr',str(file)],text=True));(file.with_suffix('.ocr.json')).write_text(json.dumps(rows,indent=2))
 im=Image.open(file).convert('RGB'); w,h=im.size
 island='expanded' in file.name;xxxl='XXXL' in file.name
 expected=2 if island and xxxl else 3 if island else 4 if xxxl else 5
 originals=[r for r in rows if re.match(r'Demo [0-9]+:',r['text'])]
 footer=[r for r in rows if re.fullmatch(r'\+[0-9]+ more',r['text'])]
 assert len(originals)==expected,(file,expected,originals)
 assert len(footer)==1,(file,footer)
 assert footer[0]['text']==f'+{10-expected} more',(file,footer)
 checks=[]
 for row in originals+footer:
  x,y,bw,bh=row['box'];x0,y0,x1,y1=round(x*w),round(y*h),round((x+bw)*w),round((y+bh)*h)
  assert (y1-y0)>= (32 if xxxl else 22),(file,'clipped OCR height',row)
  checks.append({'text':row['text'],'inkBox':[x0,y0,x1,y1]})
  if island: assert x0>=90 and x1<=w-90 and y1<=450,(file,'Island side/bottom bounds',row)
  if island and row is footer[0]:
   # All white text ink must have a black 8pt clearance below it;
   # test every column, including every footer digit, against native pill pixels.
   for cx in range(x0,x1):
    for cy in range(y1+3,y1+24):
     assert max(im.getpixel((cx,cy)))<45,(file,'corner/base clearance',cx,cy)
  elif not island:
   assert x0>=40 and x1<=w-40,(file,'banner side clearance')
 for a,b in zip(checks,checks[1:]):assert b['inkBox'][1]-a['inkBox'][3]>=4,(file,'row baselines overlap')
 results.append({'file':file.name,'originals':expected,'hidden':10-expected,'rows':checks,'footerRecognizedEveryDigit':footer[0]['text'],'islandBlackClearancePixels':24 if island else None})
assert len(results)==8,len(results)
(p.parent/(sys.argv[1]+'-native-gates.json')).write_text(json.dumps(results,indent=2));print('8 native surfaces passed OCR/count/ink-height/row-separation/clearance gates')
