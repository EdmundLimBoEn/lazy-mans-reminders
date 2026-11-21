"""Read-only frozen-S witness install, then guaranteed tested-app restoration.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import subprocess,json,hashlib,datetime
p=Path(__file__).parent;v=Path('hillclimb/validation/round7');device='78F5A64F-7B2E-4562-8EF9-10F3312CC694';bundle='systems.edmundlim.NotepadHillclimb';old=Path('/tmp/hillclimb-signin-density-DD/Build/Products/Debug-iphonesimulator/LazyMansReminders.app');new=Path('/tmp/hillclimb-login-U-DD/Build/Products/Debug-iphonesimulator/LazyMansReminders.app');rows=[]
assert json.loads((v/'final-manual-restoration.json').read_text())['allFourMatch']
freeze=json.loads((p/'freeze.json').read_text());assert all(hashlib.sha256(Path(f).read_bytes()).hexdigest()==h for f,h in freeze['hashes'].items())
before=json.loads((p/'before-binary.json').read_text());assert all(hashlib.sha256(Path(f).read_bytes()).hexdigest()==h['expected']==h['actual'] for f,h in before.items())
tested=json.loads((p/'tested-artifacts.json').read_text());assert all(hashlib.sha256(Path(f).read_bytes()).hexdigest()==h for f,h in tested.items())
def install(app,phase):
 cmd=['xcrun','simctl','install',device,str(app)];r=subprocess.run(cmd,capture_output=True,text=True);r.check_returncode();installed=Path(subprocess.check_output(['xcrun','simctl','get_app_container',device,bundle,'app'],text=True).strip());keys=['LazyMansReminders','LazyMansReminders.debug.dylib','Info.plist','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension.debug.dylib','PlugIns/ReminderWidgetExtension.appex/Info.plist'];files=[]
 for k in keys:
  a=hashlib.sha256((app/k).read_bytes()).hexdigest();b=hashlib.sha256((installed/k).read_bytes()).hexdigest();assert a==b;files.append(dict(file=k,buildSHA256=a,installedSHA256=b))
 rows.append(dict(phase=phase,command=cmd,exit=r.returncode,installedPath=str(installed),files=files,allMatch=True,timeUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),sourceSHA='c8da74021a7d66d95d040817405044bbb3af3f9f' if phase=='before' else None,sourceIdentity=None if phase=='before' else freeze['sourceIdentity']));(p/'filled-pair-binary-transitions.json').write_text(json.dumps(rows,indent=2));print(phase,'six installed app/widget hashes match',flush=True)
subprocess.run(['python3',str(p/'manual.py'),'close',bundle],check=True)
install(old,'before')
try:r=subprocess.run(['python3',str(p/'capture-filled-pairs.py'),'before'])
finally:install(new,'after')
r.check_returncode();subprocess.run(['python3',str(p/'capture-filled-pairs.py'),'after'],check=True)
assert all(hashlib.sha256(Path(f).read_bytes()).hexdigest()==h for f,h in freeze['hashes'].items())
print('Eight matched ordinary-filled pairs complete; tested combined app restored',flush=True)
