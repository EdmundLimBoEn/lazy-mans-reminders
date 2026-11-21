"""Native footer frame/raster witnesses. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,json,re,ast,hashlib
from PIL import Image
p=pathlib.Path(__file__).parent; d=p/'focused-SignInChromeUITests'; manifest=json.loads((d/'manifest.json').read_text()); attachments=manifest[0]['attachments']; rows=[]
for style in ['light','dark']:
 for size in ['default','XXXL']:
  def attachment(state,ext):
   a=next(a for a in attachments if a['suggestedHumanReadableName'].startswith(f'gesture-{style}-{size}-{state}') and a['exportedFileName'].endswith(ext));return d/a['exportedFileName']
  text=attachment('bottom','.txt').read_text().splitlines()[0]; safe=float(re.search(r'safeBottom=([\d.]+)',text)[1]); initial=ast.literal_eval(re.search(r'initial=(\[.*?\])',text)[1]); bottom=ast.literal_eval(re.search(r'links=(\[.*?\])',text)[1]); comparison=attachment('paint-comparison','.txt').read_text().splitlines()[0]; paint=ast.literal_eval(re.search(r'enabledPaint=(\[.*?\])',comparison)[1]); image=Image.open(attachment('bottom','.png')).convert('RGB'); gates=[]
  for index,name in enumerate(['Privacy','Terms','Support']):
   x,y,w,h=bottom[index]; crop=image.crop((round(x*3),round(y*3),round((x+w)*3),round((y+h)*3)));ink=sum(all(v<210 for v in pixel) if style=='light' else all(v>45 for v in pixel) for pixel in crop.getdata()); clearance=safe-y-h
   assert clearance>=8 and ink>20
   assert all(abs(bottom[index][j]-paint[index][j])<=1 for j in [0,2,3])
   gates.append(dict(name=name,nativeAXFrame=bottom[index],paintAXFrame=paint[index],safeBottomClearance=clearance,disabledInkPixels=ink,absolutePaintOffsetY=paint[index][1]-y))
  delta=initial[0][1]-bottom[0][1]
  if size=='XXXL':assert delta>20 and initial[0][1]+initial[0][3]>safe
  rows.append(dict(style=style,size=size,safeBottom=safe,footerDelta=delta,links=gates))
(p/'gesture-native-gates.json').write_text(json.dumps(rows,indent=2))
print(json.dumps(rows,indent=2))
