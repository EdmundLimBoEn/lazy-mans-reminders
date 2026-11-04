"""Native ActivityKit captures; only the pinned session drives UI.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import subprocess, pathlib, json, time
A='/Users/limboenedmund/.t3/userdata/device/targets/t3-0b2ac98e0d8e3cbeb9e4f3ac/agent-device'
O=pathlib.Path('hillclimb/tasks/activity-overflow/native')
O.mkdir(parents=True,exist_ok=True)
def run(*args):
 r=subprocess.run([A,*args],text=True,capture_output=True)
 p=O/'navigation.json'; entries=json.loads(p.read_text()) if p.exists() else []
 entries.append({'argv':[A,*args], 'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});p.write_text(json.dumps(entries,indent=2)+'\n')
 print(r.stdout[-2000:],flush=True);r.check_returncode()
def capture(surface,style,size):
 subprocess.run(['python3','hillclimb/tasks/activity-overflow/capture-state.py','--command',A,'--out',str(O),'--style',style,'--size',size,'--text','multiline','--surface',surface],check=True)
for style in ['light','dark']:
 for size in ['default','XXXL']:
  capture('prepare',style,size);time.sleep(3)
  container=subprocess.check_output(['xcrun','simctl','get_app_container','78F5A64F-7B2E-4562-8EF9-10F3312CC694','systems.edmundlim.NotepadHillclimb','data'],text=True).strip()
  record=pathlib.Path(container)/'Documents/hillclimb-activity.json'
  (O/f'pipeline-{style}-{size}.json').write_bytes(record.read_bytes())
  run('open','com.apple.springboard');run('snapshot','-i');time.sleep(2)
  capture('expanded',style,size)
  run('open','com.apple.springboard');run('swipe','180','5','180','650');time.sleep(3);run('snapshot','-i')
  capture('notification-center',style,size)
  capture('end',style,size)
run('settings','appearance','light');run('settings','text-size','large')
