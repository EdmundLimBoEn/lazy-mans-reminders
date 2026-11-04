"""Export completed authoritative run, preserving command results.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import subprocess,pathlib,json,time
p=pathlib.Path(__file__).parent; commands=[]
def run(cmd):
 start=time.time();r=subprocess.run(cmd,capture_output=True,text=True)
 commands.append(dict(command=cmd,exit=r.returncode,elapsed=time.time()-start,stdout=r.stdout,stderr=r.stderr))
 (p/'post-process.json').write_text(json.dumps(commands,indent=2))
 print(' '.join(cmd[:4]),'exit',r.returncode,flush=True);r.check_returncode()
run(['python3',str(p/'export.py'),'full'])
for test,out in [('SignInChromeUITests','full'),('AccessibilitySettingsUITests','full-settings')]:
 run(['xcrun','xcresulttool','export','attachments','--path','/tmp/hillclimb-O-full.xcresult','--test-id',test,'--output-path',str(p/out)])
for script in ['verify.py','restoration.py']:
 run(['python3',str(p/script)])
run(['python3',str(p/'collect.py'),'full'])
