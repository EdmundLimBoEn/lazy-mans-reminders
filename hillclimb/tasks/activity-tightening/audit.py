"""Verify native and test provenance. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
from pathlib import Path
import hashlib, json, subprocess, tempfile, sys
from PIL import Image
p=Path(__file__).parent
h=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
mode=sys.argv[1]
if mode=='tests':
 name=sys.argv[2]
 def cases(f):
  result={}
  def visit(n):
   if n.get('nodeType')=='Test Case':result[n['nodeIdentifierURL']]=n['result']
   for c in n.get('children',[]):visit(c)
  for n in json.loads(f.read_text())['testNodes']:visit(n)
  return result
 actual=cases(p/(name+'-tests.json'))
 baselines={str(f):cases(f) for f in [Path('hillclimb/validation/round4/combined-tests.json'),Path('hillclimb/validation/round5/combined-tests.json')]}
 for f,b in baselines.items():assert b.keys()<=actual.keys(),(f,b.keys()-actual.keys())
 assert len(actual)==293 and all(v=='Passed' for v in actual.values())
 s=json.loads((p/(name+'-summary.json')).read_text());assert s['totalTestCount']==s['passedTests']==293 and s['failedTests']==s['skippedTests']==0
 (p/(name+'-acceptance.json')).write_text(json.dumps(dict(tests=293,unit=263,ui=30,baselineRetained={f:len(b) for f,b in baselines.items()},allNamedTestsPassed=True,failed=0,skipped=0,runtimeWarnings=s['runtimeWarnings']),indent=2))
elif mode=='videos':
 records=[]
 with tempfile.TemporaryDirectory(prefix='activity-tightening-frame-') as tmp:
  for f in sorted(p.glob('*/*.mp4')):
   frame=Path(tmp)/'frame.png';cmd=['ffmpeg','-y','-v','error','-i',str(f),'-ss','2','-frames:v','1',str(frame)];subprocess.run(cmd,check=True)
   assert Image.open(frame).tobytes()==Image.open(f.with_suffix('.png')).tobytes()
   records.append(dict(file=str(f),sha256=h(f),frameSHA256=h(f.with_suffix('.png')),unmodified2sFrameVerified=True,command=cmd))
 (p/'video-verification.json').write_text(json.dumps(records,indent=2))
elif mode=='installed':
 matrix=sys.argv[2];app=Path(subprocess.check_output(['xcrun','simctl','get_app_container','78F5A64F-7B2E-4562-8EF9-10F3312CC694','systems.edmundlim.NotepadHillclimb','app'],text=True).strip());built=Path('/tmp/activity-tightening-DD/Build/Products/Debug-iphonesimulator/LazyMansReminders.app');names=['LazyMansReminders','LazyMansReminders.debug.dylib','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension.debug.dylib'];records={n:dict(built=h(built/n),installed=h(app/n)) for n in names if (built/n).exists()};assert all(v['built']==v['installed'] for v in records.values());(p/(matrix+'-installed.json')).write_text(json.dumps(records,indent=2))
print('audit',mode,'passed')
