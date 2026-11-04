"""Task-local execution evidence. Written by gpt-6.1-sol in Codex on behalf of Edmund"""
import subprocess,json,pathlib,sys,hashlib
p=pathlib.Path(__file__).parent
name=sys.argv[1]
run=next(pathlib.Path('/tmp/notepad-keyboard-recovery-dd/Build/Products').glob('*.xctestrun'))
cmd=['xcodebuild','test-without-building','-xctestrun',str(run),'-destination','platform=iOS Simulator,id=8E8380DE-364D-4899-99B8-D15ED0494FFD','-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','120','-maximum-test-execution-time-allowance','180','-collect-test-diagnostics','never','-disableAutomaticPackageResolution','-skipPackageUpdates','-resultBundlePath',f'/tmp/notepad-keyboard-{name}.xcresult','CODE_SIGNING_ALLOWED=NO']+sys.argv[2:]
(p/f'{name}-source.json').write_text(json.dumps({str(f):hashlib.sha256(f.read_bytes()).hexdigest() for d in ['ios/App','ios/Shared','ios/UITests','ios/Tests'] for f in pathlib.Path(d).glob('*.swift')},indent=2))
(p/f'{name}-command.json').write_text(json.dumps(cmd,indent=2))
r=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True); observations=[]
for line in r.stdout:
 if any(s in line for s in ['warning:','Invalid frame','error:','failed','Executed ','Test Suite','passed (','Testing ']):
  print(line,end='',flush=True); observations.append(line.strip())
code=r.wait()
(p/f'{name}-process.json').write_text(json.dumps({'exit':code,'observations':observations},indent=2))
for kind in ['summary','tests']:
 q=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path',f'/tmp/notepad-keyboard-{name}.xcresult'],capture_output=True,text=True)
 (p/f'{name}-{kind}.json').write_text(q.stdout or q.stderr)
raise SystemExit(code)
