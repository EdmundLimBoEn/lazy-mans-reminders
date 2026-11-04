import pathlib,json,hashlib,re
from PIL import Image,ImageDraw
p=pathlib.Path(__file__).resolve().parent
root=p.parents[2]
records=[]
for test in json.loads((p/'full/manifest.json').read_text()):
 for a in test['attachments']:
  name=a['suggestedHumanReadableName']; f=p/'full'/a['exportedFileName']
  if name.startswith('chrome-') and f.suffix=='.png':
   records.append(dict(path=str(f.relative_to(root)),name=name.split('_0_')[0],origin='native XCTest; focused secure content may be protected'))
for f in sorted(p.glob('final-native-*.png')):
 records.append(dict(path=str(f.relative_to(root)),name=f.stem,origin='native pinned agent-device; full keyboard'))
for r in records:
 f=pathlib.Path(r['path']);r['sha256']=hashlib.sha256(f.read_bytes()).hexdigest();r['dimensions']=Image.open(f).size
 name=r['name'];style='dark' if '-dark-' in name else 'light';size='XXXL' if '-XXXL-' in name else 'default'
 keyboardLike=('password' in name or 'native' in name) and ('focused' in name) and 'dismissed' not in name
 if size=='XXXL':
  ref=pathlib.Path(f'hillclimb/reference/round3/reminders-{"compose" if keyboardLike else "bottom"}-{style}-XXXL.png')
 elif keyboardLike:
  ref=pathlib.Path('hillclimb/reference/reminders-compose-light.png' if style=='light' else 'hillclimb/reference/round2/reminders-compose-dark.png')
 else:
  ref=pathlib.Path('hillclimb/reference/round2/reminders-bottom-light.png' if style=='light' else 'hillclimb/reference/reminders-bottom-dark.png')
 r['reference']=str(ref);r['referenceSHA256']=hashlib.sha256(ref.read_bytes()).hexdigest();r['referenceLimit']='Reminders keyboard/top/bottom treatment only; no exact Apple sign-in counterpart'
(p/'native-inventory.json').write_text(json.dumps(records,indent=2))
assert len(records)>=24
for start in range(0,len(records),12):
 chunk=records[start:start+12]; sheet=Image.new('RGB',(900,4*690),'#dddddd');d=ImageDraw.Draw(sheet)
 for i,r in enumerate(chunk):
  im=Image.open(r['path']);im.thumbnail((295,640));x=(i%3)*300;y=(i//3)*690;sheet.paste(im,(x,y));d.text((x+4,y+642),r['name'][:45],fill='black');d.text((x+4,y+657),r['name'][45:90],fill='black')
 sheet.save(p/f'contact-{start//12+1:02}.jpg')
print(len(records),'native captures inventoried')
