"""Fresh combined execution evidence. Written by gpt-6.1-sol in Codex on behalf of Edmund"""
import subprocess,pathlib,json,hashlib,datetime,sys
p=pathlib.Path('hillclimb/tasks/signin-native');dd='/tmp/notepad-signin-native-90ae0aca-dd';device='8E8380DE-364D-4899-99B8-D15ED0494FFD'
def run(name,cmd):
 start=datetime.datetime.now(datetime.timezone.utc).isoformat();r=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);lines=[]
 for line in r.stdout:
  if any(s in line for s in ['warning:','error:','SUCCEEDED','FAILED','Executed ','failed','Invalid frame']): print(line,end='',flush=True);lines.append(line.strip())
 code=r.wait();(p/(name+'.json')).write_text(json.dumps({'command':cmd,'exit':code,'startedUTC':start,'endedUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'observations':lines},indent=2));return code
base=['-project','ios/LazyMansReminders.xcodeproj','-scheme','LazyMansReminders','-destination','platform=iOS Simulator,id='+device,'-derivedDataPath',dd,'ARCHS=arm64','ONLY_ACTIVE_ARCH=YES','CODE_SIGNING_ALLOWED=NO']
mode=sys.argv[1]
if mode=='setup': sys.exit(run('resolve',['xcodebuild','-resolvePackageDependencies',*base]))
base+=['-disableAutomaticPackageResolution','-skipPackageUpdates']
if mode in ['Debug','Release']:
 code=run('build-'+mode,['xcodebuild','build-for-testing' if mode=='Debug' else 'build',*base,'-configuration',mode]);app=pathlib.Path(dd)/'Build/Products'/f'{mode}-iphonesimulator/LazyMansReminders.app'
 (p/(mode+'-artifact.json')).write_text(json.dumps({'exists':app.exists(),'binary_sha256':hashlib.sha256((app/'LazyMansReminders').read_bytes()).hexdigest() if app.exists() else None},indent=2));sys.exit(code)
if mode.startswith('matrix') or mode=='combined':
 runs=list((pathlib.Path(dd)/'Build/Products').glob('*.xctestrun'));assert len(runs)==1
 (p/'provenance.json').write_text(json.dumps({'sourceSHA':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'source_hashes':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for folder in ['ios/App','ios/Shared','ios/Widget','ios/Tests','ios/UITests'] for f in pathlib.Path(folder).rglob('*.swift')}},indent=2))
 result='/tmp/notepad-signin-native-90ae0aca-'+mode+'.xcresult'
 code=run(mode+'-process',['xcodebuild','test-without-building','-xctestrun',str(runs[0]),'-destination','platform=iOS Simulator,id='+device,'-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','180','-maximum-test-execution-time-allowance','240','-collect-test-diagnostics','never','-disableAutomaticPackageResolution','-skipPackageUpdates','-resultBundlePath',result,'CODE_SIGNING_ALLOWED=NO'] + (['-only-testing:HillclimbUITests/SignInSurfaceUITests/testFocusedEmailAndPasswordClearKeyboardInBothAppearances'] if mode.startswith('matrix') else []))
 for kind in ['summary','tests']:
  r=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path',result],capture_output=True,text=True);(p/(mode+'-'+kind+'.json')).write_text(r.stdout or r.stderr)
 sys.exit(code)
