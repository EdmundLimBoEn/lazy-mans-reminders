"""Finish serial build/offline checks only after accepted full-suite evidence.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import hashlib,json,subprocess,sys,datetime
p=Path('hillclimb/tasks/login-focus-polish')
accepted=json.loads((p/'acceptance.json').read_text())
assert accepted['status']=='passed' and accepted['passed']==325 and accepted['failed']==accepted['skipped']==0
runner=[sys.executable,str(p/'run-check.py')]
base=['xcodebuild','-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-derivedDataPath','/tmp/hillclimb-focus-PM-DD','-destination','platform=iOS Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694','-disableAutomaticPackageResolution','-skipPackageUpdates','CODE_SIGNING_ALLOWED=NO','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES']
def run(label,args):subprocess.run(runner+[label]+args,check=True)
run('bounded-matrix-release',base+['-configuration','Release','build'])
run('round8-python',['python3','-B','-m','unittest','discover','-s','scripts/tests','-p','test_ios*.py'])
run('round8-deno',['deno','test','--cached-only','supabase/functions/_shared/live_activity_test.ts','supabase/functions/_shared/board_loader_test.ts','supabase/functions/_shared/device_delivery_test.ts'])
run('round8-deno-overflow',['deno','test','--cached-only','hillclimb/tasks/activity-overflow/offline-apns_test.ts'])
run('bounded-matrix-debug-restore',base+['-configuration','Debug','build-for-testing'])
old=json.loads((p/'bounded-matrix-tested-binaries.json').read_text())
actual={k:hashlib.sha256(Path(k).read_bytes()).hexdigest() for k in old}
proof={'allMatch':actual==old,'before':old,'after':actual,'atUTC':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(p/'debug-restoration-identity.json').write_text(json.dumps(proof,indent=2)+'\n');assert proof['allMatch']
app=Path('/tmp/hillclimb-focus-PM-DD/Build/Products/Debug-iphonesimulator/LazyMansReminders.app')
subprocess.run(['xcrun','simctl','install','78F5A64F-7B2E-4562-8EF9-10F3312CC694',str(app)],check=True)
installed=Path(subprocess.check_output(['xcrun','simctl','get_app_container','78F5A64F-7B2E-4562-8EF9-10F3312CC694','systems.edmundlim.NotepadHillclimb','app'],text=True).strip())
files=['LazyMansReminders','LazyMansReminders.debug.dylib','__preview.dylib','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension','PlugIns/ReminderWidgetExtension.appex/ReminderWidgetExtension.debug.dylib','PlugIns/ReminderWidgetExtension.appex/__preview.dylib']
rows=[]
for name in files:
 a=hashlib.sha256((app/name).read_bytes()).hexdigest();b=hashlib.sha256((installed/name).read_bytes()).hexdigest();rows.append({'file':name,'builtSHA256':a,'installedSHA256':b,'equal':a==b})
proof={'allSixMatch':len(rows)==6 and all(x['equal'] for x in rows),'installedApp':str(installed),'files':rows,'atUTC':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(p/'final-installed-identity.json').write_text(json.dumps(proof,indent=2)+'\n');assert proof['allSixMatch']
print('Release/offline/Debug restore passed;all tested artifacts and six installed executables match',flush=True)
