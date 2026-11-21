"""Run unchanged combined suite and retain structured results and runtime warnings.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import subprocess,pathlib,json
p=pathlib.Path('hillclimb/tasks/activity-overflow'); runs=list(pathlib.Path('/tmp/activity-overflow-dd/Build/Products').glob('*.xctestrun'));assert len(runs)==1,runs
cmd=['xcodebuild','test-without-building','-xctestrun',str(runs[0]),'-destination','platform=iOS Simulator,id=78F5A64F-7B2E-4562-8EF9-10F3312CC694','-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','120','-maximum-test-execution-time-allowance','180','-collect-test-diagnostics','never','-disableAutomaticPackageResolution','-skipPackageUpdates','-resultBundlePath','/tmp/activity-overflow-passing.xcresult','CODE_SIGNING_ALLOWED=NO']
(p/'test-command.json').write_text(json.dumps(cmd,indent=2)+'\n')
r=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True); warnings=[]; counts=[]
for line in r.stdout:
 if any(s in line for s in ['warning:','Invalid frame','error:','failed','Executed ','Test Suite','passed (','Testing ']):print(line,end='',flush=True)
 if 'Invalid frame' in line or 'warning:' in line:warnings.append(line.strip())
 if 'Executed ' in line:counts.append(line.strip())
code=r.wait();(p/'test-process.json').write_text(json.dumps({'exit':code,'warnings':warnings,'count_lines':counts},indent=2)+'\n')
for kind in ['summary','tests']:
 q=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path','/tmp/activity-overflow-passing.xcresult'],capture_output=True,text=True);(p/('combined-'+kind+'.json')).write_text(q.stdout or q.stderr)
raise SystemExit(code)
