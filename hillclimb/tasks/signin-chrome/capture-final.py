"""Pinned native captures; stop on any failed action.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,subprocess,json
p=pathlib.Path(__file__).parent

def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True);print(r.stdout,flush=True);r.check_returncode();return r.stdout
for style in ['light','dark']:
 for size in ['default','XXXL']:
  args=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant','password-keyboard']
  op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+v for v in args])
  op('snapshot','-i')
  op('fill','role=securetextfield label="Password"','offline-only')
  op('wait','stable','1000','10000')
  snap=op('snapshot','-i');assert '[keyboard]' in snap
  name=f'final-native-{style}-{size}'
  (p/(name+'-focused.txt')).write_text(snap)
  op('screenshot',str(p/(name+'-focused.png')),'--pixel-density','3')
  op('press','role=button label="Done"')
  op('wait','stable','1000','10000')
  op('screenshot',str(p/(name+'-dismissed.png')),'--pixel-density','3')
  op('swipe','201','745','201','310')
  op('wait','stable','1000','10000')
  snap=op('snapshot','-i');(p/(name+'-bottom.txt')).write_text(snap)
  op('screenshot',str(p/(name+'-bottom.png')),'--pixel-density','3')
