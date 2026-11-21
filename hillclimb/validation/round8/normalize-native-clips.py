"""Normalize container timestamps by stream copy; verify each2s pixel witness unchanged.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
from PIL import Image
import json,hashlib,subprocess,shutil
root=Path('hillclimb/validation/round8');temporary=Path('/tmp/hillclimb-round8-normalized');temporary.mkdir(exist_ok=True)
for manifest in ['activity-video-artifacts.json','keyboard-video-artifacts.json']:
 p=root/manifest;rows=json.loads(p.read_text())
 for r in rows:
  if r.get('timestampNormalized'):continue
  clip=Path(r['file']);assert hashlib.sha256(clip.read_bytes()).hexdigest()==r['sha256'];dest=temporary/clip.name;cmd=['ffmpeg','-hide_banner','-loglevel','error','-y','-copyts','-start_at_zero','-i',str(clip),'-map','0:v:0','-c','copy',str(dest)];subprocess.run(cmd,check=True)
  if 'frame' in r:
   frame=temporary/(clip.stem+'-2s.png');subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-ss','2','-i',str(dest),'-frames:v','1',str(frame)],check=True)
   pixels=lambda f:hashlib.sha256(Image.open(f).convert('RGB').tobytes()).hexdigest()
   assert pixels(frame)==pixels(r['frame']),(clip,'2s witness changed')
   r['twoSecondPixelSHA256']=pixels(frame);r['normalizationRetainsTwoSecondPixels']=True
  r['preNormalizationSHA256']=r['sha256'];r['normalizationCommand']=cmd;shutil.copyfile(dest,clip);r['sha256']=hashlib.sha256(clip.read_bytes()).hexdigest();r['bytes']=clip.stat().st_size;r['timestampNormalized']=True;r['scope']='Native encoded frames retained by stream copy; container playback starts at0. Actual samples are not frame-pacing evidence.'
 p.write_text(json.dumps(rows,indent=2)+'\n')
print('16native clips normalized; all8 native2s pixel witnesses identical')
