"""Build metadata without storing build output. Written by gpt-6.1-sol in Codex on behalf of Edmund"""
import subprocess,json,pathlib,hashlib
p=pathlib.Path(__file__).parent
cmd=['xcodebuild','build-for-testing','-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-configuration','Debug','-destination','platform=iOS Simulator,id=8E8380DE-364D-4899-99B8-D15ED0494FFD','-derivedDataPath','/tmp/notepad-keyboard-recovery-dd','-disableAutomaticPackageResolution','-skipPackageUpdates','CODE_SIGNING_ALLOWED=NO']
r=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);lines=[]
for line in r.stdout:
 if any(s in line for s in ['warning:','error:','SUCCEEDED','FAILED']):print(line,end='',flush=True);lines.append(line.strip())
code=r.wait();app=pathlib.Path('/tmp/notepad-keyboard-recovery-dd/Build/Products/Debug-iphonesimulator/LazyMansReminders.app/LazyMansReminders')
(p/'build.json').write_text(json.dumps({'command':cmd,'exit':code,'observations':lines,'binary_sha256':hashlib.sha256(app.read_bytes()).hexdigest()},indent=2))
raise SystemExit(code)
