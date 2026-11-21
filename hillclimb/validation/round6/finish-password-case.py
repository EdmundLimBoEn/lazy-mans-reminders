"""Finish the advised native fill correction without repeating completed captures.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
from pathlib import Path
import subprocess,sys
p=Path(__file__).parent;out=Path('hillclimb/rounds/6/signin-chrome-manual');name='final-native-normal-dark-XXXL'
def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr);r.check_returncode()
 return r.stdout
op('wait','stable','1000','10000');snapshot=op('snapshot','-i');assert '[keyboard]' in snapshot and 'AutoFill' not in snapshot
(out/(name+'-focused.txt')).write_text(snapshot)
for state in ['focused','dismissed','bottom']:
 if state=='dismissed':op('press','role=button label="Done"','--settle')
 if state=='bottom':op('swipe','201','745','201','310');op('wait','stable','1000','10000');(out/(name+'-bottom.txt')).write_text(op('snapshot','-i'))
 f=out/(name+'-'+state+'.png');assert not f.exists();op('screenshot',str(f),'--pixel-density','3');print(f,flush=True)
