"""Pinned native captures; stop on any failed action.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,subprocess,json,sys
configuration=sys.argv[1]
assert configuration in ["normal","combined"]
out=pathlib.Path("hillclimb/rounds/6/signin-chrome-manual")
out.mkdir(parents=True,exist_ok=True)
p=pathlib.Path(__file__).parent

def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True);
 if r.returncode: print(r.stdout+r.stderr,flush=True)
 elif args[0] in ['open','screenshot']: print(r.stdout,flush=True)
 r.check_returncode();return r.stdout
for style in ['light','dark']:
 for size in ['default','XXXL']:
  op('settings','appearance',style)
  op('settings','text-size','large' if size=='default' else 'extra-extra-extra-large')
  args=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant','password-keyboard']
  op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+v for v in args])
  op('wait','stable','1000','10000')
  ready=op('snapshot','-i')
  if '[button] "Done"' in ready:op('press','role=button label="Done"','--settle')
  op('fill','role=securetextfield label="Password"','offline-only')
  op('wait','stable','1000','10000')
  snap=op('snapshot','-i');assert '[keyboard]' in snap and 'AutoFill' not in snap
  name=f'final-native-{configuration}-{style}-{size}'
  (out/(name+'-focused.txt')).write_text(snap)
  op('screenshot',str(out/(name+'-focused.png')),'--pixel-density','3')
  op('press','role=button label="Done"')
  op('wait','stable','1000','10000')
  op('screenshot',str(out/(name+'-dismissed.png')),'--pixel-density','3')
  op('swipe','201','745','201','310')
  op('wait','stable','1000','10000')
  snap=op('snapshot','-i');(out/(name+'-bottom.txt')).write_text(snap)
  op('screenshot',str(out/(name+'-bottom.png')),'--pixel-density','3')
