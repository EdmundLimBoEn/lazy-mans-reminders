"""Compact task-local exports. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import subprocess,pathlib,sys,json,hashlib
p=pathlib.Path(__file__).parent;name=sys.argv[1]
for group in (['SignInDensityUITests','SignInChromeUITests','AccessibilitySettingsUITests'] if name in ['full','awake'] else ['SignInChromeUITests','SignInDensityUITests']):
 dest=p/(name+'-'+group)
 r=subprocess.run(['xcrun','xcresulttool','export','attachments','--path','/tmp/hillclimb-signin-density-'+name+'.xcresult','--output-path',str(dest),'--test-id',group],capture_output=True,text=True)
 r.check_returncode();print(group,'exported',flush=True)
