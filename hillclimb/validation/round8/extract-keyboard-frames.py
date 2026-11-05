"""Native screen-recording witnesses; protected XCTest stills remain separate.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,hashlib,subprocess,struct
src=Path('/tmp/hillclimb-focus-full-chrome-media');shots=json.loads(Path('/tmp/hillclimb-focus-round8-native-export/manifest.json').read_text());videos={t['testIdentifier']:t for t in json.loads((src/'manifest.json').read_text())};out=Path('hillclimb/rounds/8/keyboard-video-frames');out.mkdir(exist_ok=True);rows=[]
for t in shots:
 if 'EmptyPasswordFirstFocusAndRefocus' not in t['testIdentifier']:continue
 v=next(a for a in videos[t['testIdentifier']]['attachments'] if a['exportedFileName'].endswith('.mp4'));movie=src/v['exportedFileName'];moviehash=hashlib.sha256(movie.read_bytes()).hexdigest()
 for a in t['attachments']:
  if not a['exportedFileName'].endswith('.png'):continue
  name=a['suggestedHumanReadableName'].split('_0_')[0];seconds=a['timestamp']-v['timestamp'];dest=out/(name+'.png');cmd=['ffmpeg','-hide_banner','-loglevel','error','-y','-ss',str(seconds),'-i',str(movie),'-frames:v','1',str(dest)];subprocess.run(cmd,check=True);raw=dest.read_bytes();rows.append(dict(file=str(dest),sha256=hashlib.sha256(raw).hexdigest(),dimensions=list(struct.unpack('>II',raw[16:24])),sourceVideo=str(movie),sourceVideoSHA256=moviehash,seconds=seconds,sourceScreenshotTimestamp=a['timestamp'],testIdentifier=t['testIdentifier'],sourceAppSHA='46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4',appBinaryUnchanged=True,command=cmd,inspection='pending; do not claim full keyboard until inspected'))
Path('hillclimb/validation/round8/keyboard-video-frames.json').write_text(json.dumps(rows,indent=2)+'\n');print(len(rows),'native recording frames')
