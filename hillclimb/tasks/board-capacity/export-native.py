"""Export native XCTest capacity captures, geometry and AX with hashes.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json, shutil, hashlib, subprocess, sys
from PIL import Image, ImageDraw
p=Path(__file__).parent
run=sys.argv[1]
raw=p/(run+'-native');out=p/(run+'-captures');out.mkdir(exist_ok=True)
command=['xcrun','xcresulttool','export','attachments','--path','/tmp/hillclimb-board-capacity-N-'+run+'.xcresult','--output-path',str(raw),'--test-id','BoardCapacityPresentationUITests']
r=subprocess.run(command,capture_output=True,text=True)
(p/(run+'-native-export.json')).write_text(json.dumps(dict(command=command,exit=r.returncode,output=r.stdout,stderr=r.stderr),indent=2));r.check_returncode()
inventory=[]
for test in json.loads((raw/'manifest.json').read_text()):
 for a in test['attachments']:
  f=raw/a['exportedFileName'];name=a['suggestedHumanReadableName'].split('_0_')[0];ext=f.suffix
  if ext=='.txt':ext='.geometry.json' if f.read_text().startswith('{') else '.ax.txt'
  dest=out/(name+ext);shutil.copyfile(f,dest)
  if ext!='.png':continue
  size='XXXL' if 'XXXL' in name else 'default';style='dark' if '-dark-' in name else 'light';kind='compose' if 'draft' in name or 'below' in name else 'bottom' if 'bottom' in name else 'top'
  ref=Path('hillclimb/reference')/('round3' if size=='XXXL' else '')/f'reminders-{kind}-{style}{"-XXXL" if size=="XXXL" else ""}.png'
  if not ref.exists():ref=Path('hillclimb/reference/round2')/f'reminders-{kind}-{style}.png'
  inventory.append(dict(path=str(dest),sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),dimensions=Image.open(dest).size,reference=str(ref),referenceSHA256=hashlib.sha256(ref.read_bytes()).hexdigest(),gaps=['Different content; no Apple capacity counterpart; no Notes reference']))
assert len(inventory)==16
(p/(run+'-inventory.json')).write_text(json.dumps(inventory,indent=2))
ims=[]
for f in sorted(out.glob('*.png')):
 im=Image.open(f).convert('RGB');im.thumbnail((241,525));canvas=Image.new('RGB',(260,560),'#eeeeee');canvas.paste(im,(9,28));ImageDraw.Draw(canvas).text((3,6),f.stem.replace('capacity-',''),fill='black');ims.append(canvas)
for page in range(2):
 sheet=Image.new('RGB',(1040,1120),'white')
 for j,im in enumerate(ims[page*8:page*8+8]):sheet.paste(im,((j%4)*260,(j//4)*560))
 sheet.save(p/f'{run}-contact-{page+1}.jpg')
print(len(inventory),'native captures exported')
