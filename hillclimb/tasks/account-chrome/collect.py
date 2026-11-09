"""Export native XCTest evidence. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,json,sys
p=pathlib.Path(__file__).parent;name=sys.argv[1];result='/tmp/account-q-'+name+'.xcresult'
for kind in ['summary','tests']:
 r=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path',result],capture_output=True,text=True,check=True);(p/(name+'-'+kind+'.json')).write_text(r.stdout)
for cls in (['AccountChromeUITests','AccessibilitySettingsUITests'] if name=='full' else ['AccountChromeUITests']):
 d=p/(name+'-'+cls);d.mkdir(exist_ok=True)
 subprocess.run(['xcrun','xcresulttool','export','attachments','--path',result,'--output-path',str(d),'--test-id',cls],check=True)
