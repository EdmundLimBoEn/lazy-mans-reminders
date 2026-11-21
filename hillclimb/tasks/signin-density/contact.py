"""Review derivatives only; native PNGs remain original. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,sys
from PIL import Image,ImageDraw
p=pathlib.Path(__file__).parent
for name in sys.argv[1:]:
 d=p/name
 if (d/'manifest.json').exists():
  shots=[(d/a['exportedFileName'],a['suggestedHumanReadableName'].split('_0_')[0]) for t in json.loads((d/'manifest.json').read_text()) for a in t['attachments'] if a['exportedFileName'].endswith('.png')]
 else:shots=[(f,f.stem) for f in sorted(d.glob('*.png'))]
 for offset in range(0,len(shots),12):
  batch=shots[offset:offset+12];sheet=Image.new('RGB',(960,710*((len(batch)+3)//4)),'#888');draw=ImageDraw.Draw(sheet)
  for i,(f,title) in enumerate(batch):
   im=Image.open(f).convert('RGB');im.thumbnail((230,670));x=i%4*240;y=i//4*710;sheet.paste(im,(x,y));draw.text((x,y+675),title[:36],fill='white')
  sheet.save(p/f'{name}-contact-{offset//12}.jpg')
 print(name,len(shots))
