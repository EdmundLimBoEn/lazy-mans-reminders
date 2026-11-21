"""Clean full-device keyboards after a real pan under actual combined Settings.
Written by gpt-6.1-sol in Codex on behalf of Edmund.
"""
import pathlib,subprocess,json
p=pathlib.Path(__file__).parent;out=pathlib.Path('hillclimb/rounds/6/combined-keyboards');out.mkdir(parents=True,exist_ok=True)
def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True)
 if r.returncode:print(r.stdout+r.stderr,flush=True);r.check_returncode()
 return r.stdout
cases=[]
for style in ['light','dark']:
 for size in ['default','XXXL']:
  for variant in ['keyboard','password-keyboard']:
   name=f'manual-{style}-{size}-{variant}'
   op('settings','appearance',style);op('settings','text-size','large' if size=='default' else 'extra-extra-extra-large')
   launch=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant',variant]
   op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+v for v in launch]);op('wait','stable','1000','10000')
   ready=op('snapshot','-i');assert '[keyboard]' in ready
   done=json.loads(op('get','attrs','role=button label="Done"'))['rect'];bottom=done['y']-12;top=128
   record=style=='light' and size=='default' and variant=='keyboard'
   if record:op('record','start','--scope','device','--hide-touches',str((out/'combined-light-default-pan.mp4').resolve()))
   try:
    op('gesture','pan','201',str(bottom),'0',str(top-bottom),'500');op('wait','stable','1000','10000')
    snap=op('snapshot','-i');(out/(name+'.txt')).write_text(snap);assert '[keyboard]' in snap and 'AutoFill' not in snap
    alt='Use an Existing Password' if variant=='keyboard' else 'Use a Sign-In Link Instead'
    alternate=json.loads(op('get','attrs','role=button label="'+alt+'"'));done=json.loads(op('get','attrs','role=button label="Done"'))
    assert alternate['hittable'] and done['rect']['height']>=48
    clearance=done['rect']['y']-alternate['rect']['y']-alternate['rect']['height'];assert clearance>=8
    f=out/(name+'.png');assert not f.exists();op('screenshot',str(f),'--pixel-density','3')
    cases.append(dict(style=style,size=size,variant=variant,alternate=alternate,done=done,clearance=clearance,path=str(f),actualSettings='manual-enabled.json',realPan=True))
    (p/'manual-keyboard-geometry.json').write_text(json.dumps(cases,indent=2));print(name,clearance,flush=True)
   finally:
    if record:op('record','stop')
assert len(cases)==8
