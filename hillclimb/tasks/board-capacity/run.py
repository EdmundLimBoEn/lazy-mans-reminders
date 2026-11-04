"""Owned round5 execution provenance. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import subprocess,pathlib,json,datetime,hashlib,sys
p=pathlib.Path(__file__).parent; dd=pathlib.Path('/tmp/hillclimb-board-capacity-N-DD'); name=sys.argv[1]
base=['xcodebuild','-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-derivedDataPath',str(dd),'-destination','platform=iOS Simulator,id=066ECE57-46B4-414A-B53E-523775329360','-disableAutomaticPackageResolution','-skipPackageUpdates','CODE_SIGNING_ALLOWED=NO','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES']
if name.startswith('build'):
 cmd=base+['-configuration',sys.argv[2],sys.argv[3]]
else:
 runs=list((dd/'Build/Products').glob('*.xctestrun')); assert len(runs)==1
 cmd=['xcodebuild','test-without-building','-xctestrun',str(runs[0]),'-destination','platform=iOS Simulator,id=066ECE57-46B4-414A-B53E-523775329360','-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','240','-maximum-test-execution-time-allowance','300','-collect-test-diagnostics','never','-disableAutomaticPackageResolution','-skipPackageUpdates','-resultBundlePath','/tmp/hillclimb-board-capacity-N-'+name+'.xcresult','CODE_SIGNING_ALLOWED=NO',*sys.argv[2:]]
files=[*pathlib.Path('ios').rglob('*.swift'),*dd.glob('Build/Products/*.xctestrun'),*dd.glob('Build/Products/Debug-iphonesimulator/**/*.dylib'),*dd.glob('Build/Products/Debug-iphonesimulator/**/*.xctest/*'),dd/'Build/Products/Debug-iphonesimulator/LazyMansReminders.app/LazyMansReminders']
(p/(name+'-inputs.json')).write_text(json.dumps(dict(sourceSHA=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),hashes={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files if f.is_file()}),indent=2))
start=datetime.datetime.now(datetime.timezone.utc).isoformat(); proc=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True); observations=[]
for line in proc.stdout:
 if any(s in line for s in ['warning:','error:','SUCCEEDED','FAILED','Executed ','failed','Invalid frame','Test Case']): print(line,end='',flush=True); observations.append(line.strip())
code=proc.wait(); (p/(name+'-process.json')).write_text(json.dumps(dict(command=cmd,exit=code,startedUTC=start,finishedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),observations=observations),indent=2))
if not name.startswith('build'):
 for kind in ['summary','tests','insights']:
  r=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path','/tmp/hillclimb-board-capacity-N-'+name+'.xcresult'],capture_output=True,text=True);(p/(name+'-'+kind+'.json')).write_text(r.stdout or r.stderr)
sys.exit(code)
