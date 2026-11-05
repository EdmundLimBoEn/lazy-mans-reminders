"""Export native evidence; never substitute historical captures for a new run.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,subprocess,json,hashlib,sys,shutil
p=pathlib.Path(__file__).parent; name=sys.argv[1]; bundle='/tmp/hillclimb-r6-recheck-b846a915-'+name+'.xcresult'
for group in ['SignInChromeUITests']+(['AccessibilitySettingsUITests'] if name=='combined' else []):
 dest=p/(name+'-'+group)
 subprocess.run(['xcrun','xcresulttool','export','attachments','--path',bundle,'--output-path',str(dest),'--test-id',group],check=True)
 for f in dest.glob('*.png'):
  if name=='combined' or 'Ordinary' not in f.name: continue
for kind in ['metrics']:
 r=subprocess.run(['xcrun','xcresulttool','get','test-results',kind,'--path',bundle],capture_output=True,text=True);r.check_returncode();(p/(name+'-'+kind+'.json')).write_text(r.stdout)
