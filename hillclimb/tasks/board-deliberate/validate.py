"""Run the complete generated test plan and three fresh keyboard matrices.
Written by gpt-6.1-sol in Codex on behalf of Edmund
"""
import pathlib,subprocess,sys,json
O=pathlib.Path(__file__).parent
base=['xcodebuild','test-without-building','-xctestrun','/tmp/notepad-board-h-1be779b5-dd/Build/Products/LazyMansReminders_iphonesimulator27.1-arm64.xctestrun','-destination','platform=iOS Simulator,id=066ECE57-46B4-414A-B53E-523775329360','-parallel-testing-enabled','NO','-test-timeouts-enabled','YES','-default-test-execution-time-allowance','180','-maximum-test-execution-time-allowance','240','-collect-test-diagnostics','never','-disableAutomaticPackageResolution','-skipPackageUpdates','CODE_SIGNING_ALLOWED=NO']
for name,extra in [('combined',[])]+[(f'keyboard{i}',['-only-testing:HillclimbUITests/SignInSurfaceUITests/testFocusedEmailAndPasswordClearKeyboardInBothAppearances']) for i in range(1,4)]:
 result=f'/tmp/notepad-board-h-{name}.xcresult'
 r=subprocess.run([sys.executable,str(O/'run.py'),name,*base,*extra,'-resultBundlePath',result])
 for kind in ['summary','tests']:
  exported=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path',result],capture_output=True,text=True)
  (O/f'{name}-{kind}.json').write_text(exported.stdout)
  if exported.returncode:sys.exit(exported.returncode)
 if r.returncode:sys.exit(r.returncode)
 summary=json.loads((O/f'{name}-summary.json').read_text())
 if summary['failedTests'] or summary['skippedTests'] or summary['passedTests'] != (279 if name=='combined' else 1):raise RuntimeError(summary)
