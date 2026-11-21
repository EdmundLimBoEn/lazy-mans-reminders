"""Native Activity pass; inspect first prepared state before running.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import subprocess,time,json,pathlib
A='/Users/limboenedmund/.t3/userdata/device/targets/t3-575f6498c28b7806ff449831/agent-device'
O=pathlib.Path('hillclimb/rounds/2/activity');O.mkdir(parents=True,exist_ok=True)
def run(*args):
 r=subprocess.run([A,*args],text=True,capture_output=True);p=O/'navigation.json';m=json.loads(p.read_text()) if p.exists() else [];m.append({'argv':[A,*args],'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});p.write_text(json.dumps(m,indent=2)+'\n');print(r.stdout[-1800:],flush=True);r.check_returncode()
def surface(s,style,size,text):
 subprocess.run(['python3','scripts/hillclimb/activity-evidence.py','--command',A,'--out',str(O),'--style',style,'--size',size,'--text',text,'--surface',s],check=True)
for style in ('light','dark'):
 for text,size in [('short','default'),('long','XXXL')]:
  if style=='light' and text=='short': continue
  surface('prepare',style,size,text);time.sleep(3);run('open','com.apple.springboard');run('snapshot','-i');time.sleep(3)
  if text=='short':surface('collapsed',style,size,text)
  surface('expanded',style,size,text)
  run('open','com.apple.springboard');run('swipe','180','5','180','650');time.sleep(3);run('snapshot','-i');surface('notification-center',style,size,text)
  surface('end',style,size,text);time.sleep(2)
