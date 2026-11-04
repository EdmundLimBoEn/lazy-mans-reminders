"""Hash native originals separately from rendered/derived evidence. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,hashlib,re
from PIL import Image
p=pathlib.Path(__file__).parent
inventory=[];rasters=[]
for manifest in p.glob('final-*/manifest.json'):
 for test in json.loads(manifest.read_text()):
  for a in test['attachments']:
   f=manifest.parent/a['exportedFileName']; name=a['suggestedHumanReadableName']
   if f.suffix=='.png':
    inventory.append(dict(path=str(f),name=name,test=test['testIdentifier'],deviceId=a['deviceId'],sha256=hashlib.sha256(f.read_bytes()).hexdigest(),size=Image.open(f).size,kind='native XCUITest app/Settings screenshot; unmodified attachment'))
   if f.suffix=='.txt' and 'raster' in name:
    text=f.read_text();match=re.search(r'ratio=([\d.]+)',text)
    if match: rasters.append(dict(path=str(f),name=name,ratio=float(match[1]),measurement=text))
(p/'native-manifest.json').write_text(json.dumps(dict(hostId='local',deviceId='8E8380DE-364D-4899-99B8-D15ED0494FFD',device='regular iPhone 17 Pro / iOS 26.2',testInputs='final-inputs.json',operations='final-*/test*-operations.json',native=inventory),indent=2))
(p/'raster-results.json').write_text(json.dumps(dict(samples=rasters,minimum=min([x['ratio'] for x in rasters],default=None)),indent=2))
print(len(inventory),'native',len(rasters),'rasters')
ops=json.loads((p/'manual-operations.json').read_text());manual=[]
for o in ops:
 if o['command'][1]=='screenshot' and o['exit']==0:
  f=pathlib.Path(o['command'][2]);assert hashlib.sha256(f.read_bytes()).hexdigest()==o['sha256']
  manual.append(dict(path=str(f),sha256=o['sha256'],size=Image.open(f).size,kind='native pinned full-device PNG',accepted=f.name!='manual-motion-restored.png',operation=o['command'],capturedAfter=o['startedUTC']))
(p/'manual-native-manifest.json').write_text(json.dumps(dict(sourceInputs='final-artifacts.json',device=dict(hostId='local',id='8E8380DE-364D-4899-99B8-D15ED0494FFD'),images=manual),indent=2))
print(sum(x['accepted'] for x in manual),'accepted supplemental native PNGs; rejected',sum(not x['accepted'] for x in manual))
