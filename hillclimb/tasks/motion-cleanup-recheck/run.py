import subprocess,pathlib,json,datetime,hashlib,sys
p=pathlib.Path(__file__).parent; dd=pathlib.Path('/tmp/hillclimb-motion-7915-DD'); name=sys.argv[1]
runs=list((dd/'Build/Products').glob('*.xctestrun')); assert len(runs)==1
files=[*pathlib.Path('ios').rglob('*.swift'),runs[0],dd/'Build/Products/Debug-iphonesimulator/LazyMansReminders.app/LazyMansReminders', dd/'Build/Products/Debug-iphonesimulator/LazyMansReminders.app/LazyMansReminders.debug.dylib']
(p/(name+'-inputs.json')).write_text(json.dumps(dict(sourceSHA=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),hashes={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files if f.is_file()}),indent=2))
cmd=['xcodebuild','test-without-building','-xctestrun',str(runs[0]),'-destination','platform=iOS Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694','-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','180','-maximum-test-execution-time-allowance','240','-collect-test-diagnostics','never','-disableAutomaticPackageResolution','-skipPackageUpdates','-resultBundlePath','/tmp/hillclimb-motion-7915-'+name+'.xcresult','CODE_SIGNING_ALLOWED=NO',*sys.argv[2:]]
start=datetime.datetime.now(datetime.timezone.utc).isoformat(); proc=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True); observations=[]
for line in proc.stdout:
 if any(s in line for s in ['warning:','error:','SUCCEEDED','FAILED','Executed ','failed','Invalid frame','Test Case']): print(line,end='',flush=True); observations.append(line.strip())
code=proc.wait(); (p/(name+'-process.json')).write_text(json.dumps(dict(command=cmd,exit=code,startedUTC=start,finishedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),observations=observations),indent=2))
for kind in ['summary','tests']:
 r=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path','/tmp/hillclimb-motion-7915-'+name+'.xcresult'],capture_output=True,text=True);(p/(name+'-'+kind+'.json')).write_text(r.stdout or r.stderr)
sys.exit(code)
