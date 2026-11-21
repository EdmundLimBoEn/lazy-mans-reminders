"""Task-local build/test provenance. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import subprocess,pathlib,json,sys,time,hashlib
root=pathlib.Path(__file__).resolve().parents[3];out=root/'hillclimb/tasks/account-density';dd='/tmp/account-r-800c5513-DD'
name=sys.argv[1]
if name.startswith('build'):
 args=['xcodebuild','build-for-testing','-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-configuration','Debug','-derivedDataPath',dd]
else:
 xct=next(pathlib.Path(dd+'/Build/Products').glob('*.xctestrun'))
 args=['xcodebuild','test-without-building','-xctestrun',str(xct),'-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','240','-maximum-test-execution-time-allowance','300','-collect-test-diagnostics','never','-resultBundlePath','/tmp/account-r-'+name+'.xcresult']
 if name not in ['full','full-recheck']:args+=['-only-testing:HillclimbUITests/'+sys.argv[2]]
args+=['-destination','platform=iOS Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694,arch=arm64','-disableAutomaticPackageResolution','-skipPackageUpdates','CODE_SIGNING_ALLOWED=NO']
inputs={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['ios/App','ios/Shared','ios/Widget','ios/Tests','ios/UITests'] for p in (root/folder).rglob('*.swift')}
start=time.time();p=subprocess.Popen(args,cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);warnings=[];tests=[];tail=[]
for line in p.stdout:
 tail=(tail+[line.rstrip()])[-30:]
 if any(s in line.lower() for s in ['warning:','error:','failed','executed','succeeded']):
  print(line.rstrip(),flush=True)
  warnings.append(line.rstrip())
 if "Test Case '-[" in line:tests.append(line.rstrip())
code=p.wait();(out/(name+'.json')).write_text(json.dumps(dict(argv=args,exit=code,start=start,end=time.time(),inputs=inputs,artifacts={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in pathlib.Path(dd+'/Build/Products').rglob('*') if f.is_file() and (f.suffix in ['.dylib','.xctestrun'] or f.name in ['LazyMansReminders','HillclimbUITests','LazyMansRemindersTests'])},warnings=warnings,tests=tests,tail=tail),indent=2));print('EXIT',code,flush=True);sys.exit(code)
