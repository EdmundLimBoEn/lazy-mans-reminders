"""Native evidence contact sheets and hashes. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,hashlib,sys
from PIL import Image,ImageOps,ImageDraw
p=pathlib.Path(__file__).parent;name=sys.argv[1];cls=sys.argv[2] if len(sys.argv)>2 else 'AccountChromeUITests';d=p/(name+'-'+cls);name=name+('-density' if cls=='AccountDensityUITests' else '');out=p/name;out.mkdir(exist_ok=True);rows=[]
for test in json.loads((d/'manifest.json').read_text()):
 for a in test['attachments']:
  f=d/a['exportedFileName'];label=a.get('suggestedHumanReadableName','')
  if f.suffix!='.png' or not any(label.startswith(s) for s in ['light-','dark-']):continue
  target=out/(label.split('_0_')[0]+'.png');target.write_bytes(f.read_bytes());rows.append({'path':str(target),'name':target.stem,'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'dimensions':Image.open(f).size,'source':str(f),'appSourceSHA':('02fcee4bed50940679e10698ed8620aa08005ebc' if name.startswith('before') else json.loads((p/'freeze.json').read_text())['sourceSHA']),'binaryRecord':sys.argv[1]+'.json', 'captureKind':'Native XCTest PNG attachment'})
for i in range(0,len(rows),8):
 sheet=Image.new('RGB',(1000,1220),'#dddddd');draw=ImageDraw.Draw(sheet)
 for j,r in enumerate(rows[i:i+8]):
  im=Image.open(r['path']);im.thumbnail((240,550));x=(j%4)*250;y=(j//4)*610;sheet.paste(im,(x,y+35));draw.text((x+2,y+2),r['name'],fill='black')
 sheet.save(out/('contact-%02d.jpg'%(i//8+1)))
(p/(name+'-images.json')).write_text(json.dumps(rows,indent=2));print(name,len(rows))
