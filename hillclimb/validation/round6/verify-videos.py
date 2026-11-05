"""Native video provenance and unmodified2s Activity frames; encoded rates are not performance metrics.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,subprocess,json,hashlib,tempfile
from PIL import Image,ImageDraw
p=pathlib.Path(__file__).parent;o=pathlib.Path('hillclimb/rounds/6');records=[];samples=[]
with tempfile.TemporaryDirectory(prefix='round6-own-video-') as temp:
 for video in sorted(o.rglob('*.mp4')):
  probe=json.loads(subprocess.check_output(['ffprobe','-v','quiet','-print_format','json','-show_streams','-show_format',str(video)],text=True));duration=float(probe['format']['duration']);record=dict(file=str(video.relative_to(o)),sha256=hashlib.sha256(video.read_bytes()).hexdigest(),duration=duration,streams=probe['streams'],encodedMetadataOnly=True)
  if video.parent.name in ['activity','activity-long']:
   frame=pathlib.Path(temp)/'exact.png';subprocess.run(['ffmpeg','-y','-v','error','-i',str(video),'-ss','2','-frames:v','1',str(frame)],check=True)
   assert Image.open(frame).tobytes()==Image.open(video.with_suffix('.png')).tobytes();record['unmodified2sFrameVerified']=True
  for i,t in enumerate([duration*.15,duration*.5,duration*.85]):
   frame=pathlib.Path(temp)/f'sample-{len(samples)}.png';subprocess.run(['ffmpeg','-y','-v','error','-i',str(video),'-ss',str(t),'-frames:v','1',str(frame)],check=True);im=Image.open(frame).convert('RGB');im.thumbnail((245,410));samples.append((im.copy(),video.name,t))
  records.append(record)
 for offset in range(0,len(samples),12):
  sheet=Image.new('RGB',(1000,1380),'#777777');d=ImageDraw.Draw(sheet)
  for i,(im,name,t) in enumerate(samples[offset:offset+12]):
   x=i%4*250;y=i//4*460;sheet.paste(im,(x,y));d.text((x,y+412),name[:32],fill='white');d.text((x,y+430),f'{t:.2f}s',fill='white')
  sheet.save(p/f'video-inspection-{offset//12+1}.jpg')
(p/'video-artifacts.json').write_text(json.dumps(records,indent=2));print(len(records),'videos; Activity2s frames pixel-identical')
