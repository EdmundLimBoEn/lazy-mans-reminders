"""Sequential Release verification, Debug restore, main matrix.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import subprocess,pathlib,json,hashlib
p=pathlib.Path('hillclimb/validation/round2')
cmd=['xcodebuild','build','-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-configuration','Release','-destination','platform=iOS Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694','-derivedDataPath','/tmp/notepad-round2-dd','-disableAutomaticPackageResolution','-skipPackageUpdates','CODE_SIGNING_ALLOWED=NO','-quiet']
r=subprocess.run(cmd);(p/'build-release.json').write_text(json.dumps({'command':cmd,'exit':r.returncode,'status':'passed' if r.returncode==0 else 'failed'},indent=2)+'\n')
app='/tmp/notepad-round2-dd/Build/Products/Debug-iphonesimulator/LazyMansReminders.app'
subprocess.run(['xcrun','simctl','install','78F5A64F-7B2E-4562-8EF9-10F3312CC694',app],check=True)
(p/'debug-restore.json').write_text(json.dumps({'app':app,'binary_sha256':hashlib.sha256(pathlib.Path(app+'/LazyMansReminders').read_bytes()).hexdigest(),'installed_after_release':True},indent=2)+'\n')
subprocess.run(['scripts/hillclimb/shots.sh','--round','2','--device',str(p/'device.json'),'--command','/Users/limboenedmund/.t3/userdata/device/targets/t3-575f6498c28b7806ff449831/agent-device','--operations','scripts/hillclimb/operations.example.json'],check=True)
