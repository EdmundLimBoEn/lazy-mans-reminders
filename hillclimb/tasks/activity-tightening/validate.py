"""Owned build/test evidence. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import subprocess,pathlib,json,sys,hashlib,datetime
out=pathlib.Path(__file__).parent; dd=pathlib.Path('/tmp/activity-tightening-DD'); device='78F5A64F-7B2E-4562-8EF9-10F3312CC694'
mode=sys.argv[1]; attempt=sys.argv[2]
base=['-destination','platform=iOS Simulator,id='+device,'-disableAutomaticPackageResolution','-skipPackageUpdates','CODE_SIGNING_ALLOWED=NO']
if mode=='resolve': cmd=['xcodebuild','-resolvePackageDependencies','-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-derivedDataPath',str(dd)]
elif mode=='build': cmd=['xcodebuild','build-for-testing','-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-configuration','Debug','-derivedDataPath',str(dd),'ARCHS=arm64','ONLY_ACTIVE_ARCH=YES',*base]
else:
 runs=list((dd/'Build/Products').glob('*.xctestrun'));assert len(runs)==1
 cmd=['xcodebuild','test-without-building','-xctestrun',str(runs[0]),*base,'-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','240','-maximum-test-execution-time-allowance','300','-collect-test-diagnostics','never','-resultBundlePath','/tmp/activity-tightening-'+attempt+'.xcresult']
 if mode=='native':cmd+=['-only-testing:HillclimbUITests/ActivityNativeLayoutTests']
record={'command':cmd,'startUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in pathlib.Path('ios').rglob('*.swift')},'observations':[]}
p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
for line in p.stdout:
 if any(s in line for s in ['warning:','error:','SUCCEEDED','FAILED','Executed ','failed','Invalid frame']):print(line,end='',flush=True);record['observations'].append(line.strip())
record['exit']=p.wait();record['endUTC']=datetime.datetime.now(datetime.timezone.utc).isoformat()
(out/(attempt+'.json')).write_text(json.dumps(record,indent=2))
if mode not in ['build','resolve']:
 for kind in ['summary','tests']:
  r=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path','/tmp/activity-tightening-'+attempt+'.xcresult'],capture_output=True,text=True);(out/(attempt+'-'+kind+'.json')).write_text(r.stdout or r.stderr)
sys.exit(record['exit'])
