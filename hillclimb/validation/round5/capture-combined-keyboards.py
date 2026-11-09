"""Native full-device supplementation. Written by gpt-6.1-sol in Codex on behalf of Edmund."""
import pathlib,subprocess,json,re
p=pathlib.Path(__file__).parent
out=pathlib.Path("hillclimb/rounds/5/combined-keyboards");out.mkdir(parents=True,exist_ok=True)

def op(*args):
 r=subprocess.run(['python3',str(p/'manual.py'),*args],capture_output=True,text=True);r.check_returncode();return r.stdout
cases=[]
for style in ['light','dark']:
 for size in ['default','XXXL']:
  for variant in ['keyboard','password-keyboard']:
   name=f'manual-{style}-{size}-{variant}'
   op('settings','appearance',style);op('settings','text-size','large' if size=='default' else 'extra-extra-extra-large')
   launch=['--hillclimb-demo','signin','--hillclimb-style',style,'--hillclimb-size',size,'--hillclimb-signin-variant',variant]
   op('open','systems.edmundlim.NotepadHillclimb','--relaunch',*['--launch-args='+v for v in launch])
   op('wait','stable','1000','10000')
   ready=op('snapshot','-i')
   done=json.loads(op('get','attrs','role=button label="Done"'))['rect']
   bottom=done['y']-12;top=128 # Executed native geometry: nav maxY116 +12
   op('gesture','pan','201',str(bottom),'0',str(top-bottom),'500')
   op('wait','stable','1000','10000')
   snapshot=op('snapshot','-i');(out/(name+'.txt')).write_text(snapshot)
   assert '[keyboard]' in snapshot and 'AutoFill' not in snapshot
   alt='Use an Existing Password' if variant=='keyboard' else 'Use a Sign-In Link Instead'
   alternate=json.loads(op('get','attrs','role=button label="'+alt+'"'))
   done=json.loads(op('get','attrs','role=button label="Done"'))
   assert alternate['hittable'] and done['rect']['height']>=48
   clearance=done['rect']['y']-alternate['rect']['y']-alternate['rect']['height']
   assert clearance>=8
   png=out/(name+'.png');assert not png.exists();op('screenshot',str(png),'--pixel-density','3')
   cases.append(dict(style=style,size=size,variant=variant,alternate=alternate,done=done,clearance=clearance,path=str(png)))
   (p/'manual-keyboard-geometry.json').write_text(json.dumps(cases,indent=2));print(name,clearance,flush=True)
