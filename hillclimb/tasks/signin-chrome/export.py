import subprocess,json,pathlib,sys
p=pathlib.Path(__file__).parent
name=sys.argv[1]; bundle=f'/tmp/hillclimb-O-{name}.xcresult'
for mode in ['summary','tests']:
 r=subprocess.run(['xcrun','xcresulttool','get','test-results',mode,'--path',bundle],capture_output=True,text=True);r.check_returncode();(p/f'{name}-{mode}.json').write_text(r.stdout)
if '--attachments' in sys.argv:
 subprocess.run(['xcrun','xcresulttool','export','attachments','--path',bundle,'--output-path',str(p/name)],check=True)
