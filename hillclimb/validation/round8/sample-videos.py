"""Three visual samples per movie; no frame-pacing inference.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,subprocess,hashlib
from PIL import Image,ImageDraw
p=Path('hillclimb/validation/round8');movies=json.loads((p/'activity-video-artifacts.json').read_text())+json.loads((p/'keyboard-video-artifacts.json').read_text());out=Path('/tmp/hillclimb-round8-video-inspection');out.mkdir(exist_ok=True);rows=[]
for r in movies:
 f=Path(r['file']);meta=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=width,height','-of','json',str(f)],text=True));duration=float(meta['format']['duration']);available=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','frame=best_effort_timestamp_time','-of','json',str(f)],text=True))['frames'];indices=[int((len(available)-1)*fraction) for fraction in [0.1,0.5,0.9]];frames=[]
 for i,index in enumerate(indices):
  seconds=float(available[index]['best_effort_timestamp_time'])
  dest=out/(f.stem+f'-sample{i}.png');subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(f),'-frames:v','1','-vf',f'select=eq(n\\,{index}),scale=302:-1','-pix_fmt','rgb24',str(dest)],check=True);frames.append(dict(file=str(dest),seconds=seconds))
 rows.append(dict(file=str(f),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),duration=duration,dimensions=[meta['streams'][0]['width'],meta['streams'][0]['height']],samples=frames,decodedFrameCount=len(available),firstFramePTS=available[0]['best_effort_timestamp_time'],lastFramePTS=available[-1]['best_effort_timestamp_time']))
(p/'video-sample-inspection.json').write_text(json.dumps(dict(movies=rows,historicalSamplerFailure='Initial JPEG thumbnail encoder rejected a non-full-range source frame at9.02s. Switched inspection thumbnails to RGB PNG. A later duration-derived end sample had no decodable frame despite container metadata; sample actual decoded-frame indices at10/50/90percent instead. Native movies and native2s PNGs are unchanged.'),indent=2)+'\n')
for offset in range(0,len(rows),4):
 canvas=Image.new('RGB',(1000,4*605),'#ddd');draw=ImageDraw.Draw(canvas)
 for i,r in enumerate(rows[offset:offset+4]):
  for j,s in enumerate(r['samples']):
   im=Image.open(s['file']);im.thumbnail((300,550));canvas.paste(im,(j*330,i*605+35));draw.text((j*330+4,i*605+4),Path(r['file']).stem+f" {s['seconds']:.2f}s",fill='black')
 canvas.save(p/f'video-inspection-{offset//4+1}.jpg',quality=90)
print(len(rows),'movies sampled at3timestamps each')
