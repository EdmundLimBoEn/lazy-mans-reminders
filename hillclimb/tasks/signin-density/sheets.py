"""Review-only contact sheets; originals remain unretouched. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,sys
p=Path(__file__).parent
for phase in sys.argv[1:]:
 d=p/(phase+'-native');m=json.loads((d/'manifest.json').read_text());shots=[(d/a['exportedFileName'],a['suggestedHumanReadableName']) for t in m for a in t['attachments'] if a['exportedFileName'].endswith('.png')]
 for offset in range(0,len(shots),12):
  batch=shots[offset:offset+12];sheet=Image.new('RGB',(960,740*((len(batch)+3)//4)), '#888888');draw=ImageDraw.Draw(sheet)
  for i,(f,n) in enumerate(batch):
   im=Image.open(f).convert('RGB');im.thumbnail((230,690));x=(i%4)*240;y=(i//4)*740;sheet.paste(im,(x,y));draw.text((x,y+691),n.replace('density-','').split('_0_')[0][:34],fill='white')
  sheet.save(p/f'{phase}-contact-{offset//12}.jpg')
