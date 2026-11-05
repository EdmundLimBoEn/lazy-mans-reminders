"""Retain native encoded frames without scaling or re-encoding.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,subprocess,hashlib
raw=Path('/tmp/hillclimb-focus-full-activity-media');out=Path('hillclimb/rounds/8/video');rows=[]
for t in json.loads((raw/'manifest.json').read_text()):
 v=next(a for a in t['attachments'] if a['exportedFileName'].endswith('.mp4'));src=raw/v['exportedFileName']
 for a in t['attachments']:
  if not a['exportedFileName'].endswith('.png') or '-island_' not in a['suggestedHumanReadableName']:continue
  name=a['suggestedHumanReadableName'].split('_0_')[0];delta=a['timestamp']-v['timestamp'];clip=out/(name+'.mp4');frame=out/(name+'-2s.png')
  cmd=['ffmpeg','-hide_banner','-loglevel','error','-y','-ss',str(delta-1),'-i',str(src),'-t','4','-map','0:v:0','-c','copy','-avoid_negative_ts','make_zero',str(clip)]
  subprocess.run(cmd,check=True)
  subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-ss','2','-i',str(clip),'-frames:v','1',str(frame)],check=True)
  rows.append(dict(file=str(clip),sha256=hashlib.sha256(clip.read_bytes()).hexdigest(),bytes=clip.stat().st_size,sourceFile=str(src),sourceSHA256=hashlib.sha256(src.read_bytes()).hexdigest(),sourceAcquisitionTest=t['testIdentifier'],sourceAppSHA='46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4',gradedTestSHA='fc08b417d9a38d79c726678048100362ccfaf1ec',appBinariesUnchanged=True,command=cmd,frame=str(frame),frameAtSeconds=2,frameSHA256=hashlib.sha256(frame.read_bytes()).hexdigest(),inspection='pending',claim='Stream copy; no scale or re-encoding.2s PNG directly decoded from this committed MP4. No true lock or frame pacing claim.'))
Path('hillclimb/validation/round8/activity-video-artifacts.json').write_text(json.dumps(rows,indent=2)+'\n')
print(len(rows),'native clips and2sframes')
