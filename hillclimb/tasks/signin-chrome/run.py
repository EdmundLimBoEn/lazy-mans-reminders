import subprocess,sys,json,time,pathlib
root=pathlib.Path(__file__).resolve().parents[3]; out=root/'hillclimb/tasks/signin-chrome'; dd='/tmp/hillclimb-O-signin-DD'
base=['xcodebuild','-project',str(root/'ios/LazyMansReminders.xcodeproj'),'-scheme','LazyMansReminders','-derivedDataPath',dd,'-destination','platform=iOS Simulator,id=8E8380DE-364D-4899-99B8-D15ED0494FFD']
mode=sys.argv[1]; name=sys.argv[2] if len(sys.argv)>2 else mode
if mode=='resolve': cmd=base+['-resolvePackageDependencies']
elif mode=='build': cmd=base+['-configuration','Debug','-disableAutomaticPackageResolution','-skipPackageUpdates','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES','CODE_SIGNING_ALLOWED=NO','build-for-testing']
else:
 run=next(pathlib.Path(dd+'/Build/Products').glob('*.xctestrun'))
 cmd=['xcodebuild','test-without-building','-xctestrun',str(run),'-destination','platform=iOS Simulator,id=8E8380DE-364D-4899-99B8-D15ED0494FFD','-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','240','-maximum-test-execution-time-allowance','300','-collect-test-diagnostics','never','-disableAutomaticPackageResolution','-skipPackageUpdates','-resultBundlePath',f'/tmp/hillclimb-O-{name}.xcresult']+sys.argv[3:]
start=time.time(); lines=[]; p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
for line in p.stdout:
 if any(s in line for s in ['warning:','error:','failed','passed','SUCCEEDED','FAILED','Executed','Testing started']):
  print(line,end='',flush=True); lines.append(line.rstrip())
code=p.wait(); (out/(name+'-process.json')).write_text(json.dumps(dict(command=cmd,exit=code,start=start,elapsed=time.time()-start,diagnostics=lines),indent=2));sys.exit(code)
