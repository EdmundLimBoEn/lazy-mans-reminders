"""Pair identical named fixture states across rounds; never invent filled counterparts.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,re,textwrap
p=Path('hillclimb/rounds/8');rows=json.loads((p/'native-acquisition-inventory.json').read_text())['images'];old=json.loads(Path('hillclimb/validation/round7/xctest-native-inventory.json').read_text());pairs=[]
def key(r):return (r['testIdentifier'],r['attachmentName'].split('_0_')[0])
oldmap={key(r):r for r in old}
for r in rows:
 if not r['testIdentifier'].startswith(('LoginCompositionUITests/','SignInDensityUITests/')):continue
 before=oldmap.get(key(r))
 if not before:continue
 a=Path(before['file']);b=p/r['file'];assert hashlib.sha256(a.read_bytes()).hexdigest()==before['sha256'];pairs.append(dict(name=r['attachmentName'].split('_0_')[0],before=str(a),beforeSHA256=before['sha256'],beforeSourceSHA='e9f7ace58b493dd4aa3acb27325eaea7cf0ed352',after=str(b),afterSHA256=r['sha256'],afterAcquisitionSHA=r['acquisitionSourceSHA'],afterGradedSHA=r['gradedSourceSHA'],protectedPartial=r['protectedPartial'],relation='Same test method and named deterministic fixture; ordinary vs enabled-inert appearance retained as encoded in method'))
assert len(pairs)>=40,len(pairs)
Path('hillclimb/validation/round8/login-pairings.json').write_text(json.dumps(dict(pairs=pairs,unmatched=['New filled loading-stability fixture has no exact R7 filled/pending counterpart; not paired','New first-empty-focus/refocus tests have no identical R7 method; same-state historical keyboard comparisons remain in density matrix']),indent=2)+'\n')
out=p/'login-pairs';out.mkdir(exist_ok=True)
for offset in range(0,len(pairs),4):
 canvas=Image.new('RGB',(1100,1320),'#ddd');draw=ImageDraw.Draw(canvas)
 for i,r in enumerate(pairs[offset:offset+4]):
  x=(i%2)*550;y=(i//2)*660;draw.text((x+10,y+3),r['name'],fill='black');draw.text((x+10,y+20),'R7 before                         R8 after',fill='black')
  for j,k in enumerate(['before','after']):
   im=Image.open(r[k]).convert('RGB');im.thumbnail((270,600));canvas.paste(im,(x+j*275,y+45))
 canvas.save(out/f'page-{offset//4+1:02}.jpg',quality=92)
print(len(pairs),'exact named-state pairs')
