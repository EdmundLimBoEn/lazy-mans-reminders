"""Retain short native focus/refocus movie segments without re-encoding.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import json,collections,subprocess,hashlib
rows=json.loads(Path('hillclimb/validation/round8/keyboard-video-frames.json').read_text());groups=collections.defaultdict(list)
for r in rows:
 name=Path(r['file']).stem.rsplit('-',1)[0];groups[name].append(r)
out=Path('hillclimb/rounds/8/video');proof=[]
for name,items in sorted(groups.items()):
 start=min(r['seconds'] for r in items)-1;duration=max(r['seconds'] for r in items)-start+2;src=Path(items[0]['sourceVideo']);dest=out/(name+'.mp4');cmd=['ffmpeg','-hide_banner','-loglevel','error','-y','-ss',str(start),'-i',str(src),'-t',str(duration),'-map','0:v:0','-c','copy','-avoid_negative_ts','make_zero',str(dest)];subprocess.run(cmd,check=True);proof.append(dict(file=str(dest),sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),bytes=dest.stat().st_size,sourceVideo=str(src),sourceVideoSHA256=items[0]['sourceVideoSHA256'],requestedStart=start,requestedDuration=duration,command=cmd,sourceAppSHA='46c1a5b7ebd9ad29be3f2ffb754b8e8f347c45b4',appBinaryUnchanged=True,relatedNativeFrames=[r['file'] for r in items],inspection='pending',scope='Native first-focus/refocus recording. Stream-copy preserves encoded frames; keyframe alignment can include preceding frames. No measured frame pacing claim.'))
Path('hillclimb/validation/round8/keyboard-video-artifacts.json').write_text(json.dumps(proof,indent=2)+'\n');print(len(proof),'native keyboard clips')
