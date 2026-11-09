"""Owned round6 execution provenance. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import subprocess,pathlib,json,datetime,hashlib,sys,os
p=pathlib.Path(__file__).parent; dd=pathlib.Path('/tmp/hillclimb-signin-density-DD'); name=sys.argv[1]
base=['xcodebuild','-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-derivedDataPath',str(dd),'-destination','platform=iOS Simulator,id=8E8380DE-364D-4899-99B8-D15ED0494FFD','-disableAutomaticPackageResolution','-skipPackageUpdates','CODE_SIGNING_ALLOWED=NO','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES']
if name.startswith('build'):
 cmd=base+['-configuration',sys.argv[2],sys.argv[3]]
else:
 compiled = dd/'Build/Intermediates.noindex/LazyMansReminders.build/Debug-iphonesimulator/HillclimbUITests.build/Objects-normal/arm64/HillclimbUITests.SwiftFileList'
 included = set(compiled.read_text().splitlines())
 assert all(str(f.resolve()) in included for f in pathlib.Path('ios/UITests').glob('*.swift')), 'Generated project omitted a UI test source'
 runs=list((dd/'Build/Products').glob('*.xctestrun')); assert len(runs)==1
 cmd=['xcodebuild','test-without-building','-xctestrun',str(runs[0]),'-destination','platform=iOS Simulator,id=8E8380DE-364D-4899-99B8-D15ED0494FFD','-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','240','-maximum-test-execution-time-allowance','300','-collect-test-diagnostics','never','-disableAutomaticPackageResolution','-skipPackageUpdates','-resultBundlePath','/tmp/hillclimb-signin-density-'+name+'.xcresult','CODE_SIGNING_ALLOWED=NO',*sys.argv[2:]]
files=[*pathlib.Path('ios').rglob('*.swift'),*dd.glob('Build/Products/*.xctestrun'),*dd.glob('Build/Products/Debug-iphonesimulator/**/*.dylib'),*dd.glob('Build/Products/Debug-iphonesimulator/**/*.xctest/*'),dd/'Build/Products/Debug-iphonesimulator/LazyMansReminders.app/LazyMansReminders']
(p/(name+'-inputs.json')).write_text(json.dumps(dict(sourceSHA=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),hashes={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files if f.is_file()}),indent=2))
hostStart=dict(load=os.getloadavg(),thermal=subprocess.run(['pmset','-g','therm'],capture_output=True,text=True).stdout,processes=subprocess.check_output(['ps','-axo','pid,pcpu,comm'],text=True))
start=datetime.datetime.now(datetime.timezone.utc).isoformat(); proc=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True); observations=[]
for line in proc.stdout:
 if any(s in line for s in ['warning:','error:','SUCCEEDED','FAILED','Executed ','failed','Invalid frame','Test Case']): print(line,end='',flush=True); observations.append(line.strip())
code=proc.wait(); (p/(name+'-process.json')).write_text(json.dumps(dict(hostStart=hostStart,hostEnd=dict(load=os.getloadavg(),thermal=subprocess.run(['pmset','-g','therm'],capture_output=True,text=True).stdout),command=cmd,exit=code,startedUTC=start,finishedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),observations=observations),indent=2))
if not name.startswith('build'):
 for kind in ['summary','tests','insights']:
  r=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path','/tmp/hillclimb-signin-density-'+name+'.xcresult'],capture_output=True,text=True);(p/(name+'-'+kind+'.json')).write_text(r.stdout or r.stderr)
sys.exit(code)
